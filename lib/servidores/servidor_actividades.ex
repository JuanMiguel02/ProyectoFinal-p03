defmodule Emergencia.EstadoActividades do
  defstruct actividades: %{}
end

defmodule Emergencia.ActividadesServidor do
  use GenServer

  alias Emergencia.EstadoActividades
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioActividad
  alias Emergencia.NodoServidor

  # ===========================================================================
  # API pública
  # ===========================================================================

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar(id_usuario, accion, descripcion, opciones \\ []) do
    NodoServidor.llamar(__MODULE__, {:registrar, id_usuario, accion, descripcion, opciones})
  end

  def listar do
    NodoServidor.llamar(__MODULE__, :listar)
  end

  def listar_por_usuario(id_usuario) do
    NodoServidor.llamar(__MODULE__, {:listar_por_usuario, id_usuario})
  end

  def buscar(id_actividad) do
    NodoServidor.llamar(__MODULE__, {:buscar, id_actividad})
  end

  # ===========================================================================
  # Inicialización
  # ===========================================================================

  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:actividades) do
      {:ok, datos} ->
        estado = %EstadoActividades{
          actividades: Map.get(datos, :actividades, %{})
        }

        {:ok, estado}

      {:error, motivo} ->
        {:stop, {:error_cargando_actividades, motivo}}
    end
  end

  # ===========================================================================
  # Registro
  # ===========================================================================

  @impl true
  def handle_call({:registrar, id_usuario, accion, descripcion, opciones}, _from, estado) do
    case ServicioActividad.registrar(estado, id_usuario, accion, descripcion, opciones) do
      {:ok, actividad, nuevo_estado} ->
        case persistir(nuevo_estado) do
          :ok ->
            {:reply, {:ok, actividad}, nuevo_estado}

          {:error, motivo} ->
            {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # ===========================================================================
  # Consultas
  # ===========================================================================

  def handle_call(:listar, _from, estado) do
    {:reply, ServicioActividad.listar(estado), estado}
  end

  def handle_call({:listar_por_usuario, id_usuario}, _from, estado) do
    respuesta = ServicioActividad.listar_por_usuario(estado, id_usuario)

    {:reply, respuesta, estado}
  end

  def handle_call({:buscar, id_actividad}, _from, estado) do
    respuesta = ServicioActividad.buscar(estado, id_actividad)

    {:reply, respuesta, estado}
  end

  # ===========================================================================
  # Persistencia
  # ===========================================================================

  def persistir(%EstadoActividades{} = estado) do
    datos = %{
      actividades: estado.actividades
    }

    GestorDatos.guardar_dominio(datos, :actividades)
  end
end
