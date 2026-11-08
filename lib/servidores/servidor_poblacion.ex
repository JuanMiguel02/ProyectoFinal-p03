defmodule Emergencia.EstadoPoblacion do
  defstruct personas: %{},
            familias: %{},
            albergues: %{},
            registros_albergues: %{}
end

defmodule Emergencia.PoblacionServidor do
  use GenServer

  alias Emergencia.GestorDatos
  alias Emergencia.EstadoPoblacion
  alias Emergencia.Servicios.ServicioAlbergue

  # ============================================================================
  # API pública
  # ============================================================================

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  # ----------------------------------------------------------------------------
  # Albergues
  # ----------------------------------------------------------------------------

  def registrar_albergue(codigo, nombre, id_zona, capacidad_maxima) do
    GenServer.call(__MODULE__, {:registrar_albergue, codigo, nombre, id_zona, capacidad_maxima})
  end

  def ingresar_persona(id_persona, id_albergue) do
    GenServer.call(__MODULE__, {:ingresar_persona, id_persona, id_albergue})
  end

  def registrar_salida(id_persona, nuevo_estado_persona \\ :localizada) do
    GenServer.call(__MODULE__, {:registrar_salida, id_persona, nuevo_estado_persona})
  end

  def consultar_cupos(id_albergue) do
    GenServer.call(__MODULE__, {:consultar_cupos, id_albergue})
  end

  def consultar_ocupacion(id_albergue) do
    GenServer.call(__MODULE__, {:consultar_ocupacion, id_albergue})
  end

  def reporte_ocupacion do
    GenServer.call(__MODULE__, :reporte_ocupacion)
  end

  # ============================================================================
  # Callbacks de GenServer
  # ============================================================================

  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:poblacion) do
      {:ok, datos} ->
        estado = %EstadoPoblacion{
          personas: Map.get(datos, :personas, %{}),
          familias: Map.get(datos, :familias, %{}),
          albergues: Map.get(datos, :albergues, %{}),
          registros_albergues: Map.get(datos, :registros_albergues, %{})
        }

        {:ok, estado}

      {:error, motivo} ->
        {:stop, motivo}
    end
  end

  @impl true
  def handle_call({:registrar_albergue, codigo, nombre, id_zona, capacidad_maxima},_from,estado) do
    resultado = Emergencia.Servicios.ServicioAlbergue.registrar(estado, codigo, nombre, id_zona, capacidad_maxima)
    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:ingresar_persona, id_persona, id_albergue}, _from, estado) do
    resultado = ServicioAlbergue.ingresar_persona(estado, id_persona, id_albergue)
    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:registrar_salida, id_persona, nuevo_estado_persona}, _from, estado) do
    resultado = ServicioAlbergue.registrar_salida(estado, id_persona, nuevo_estado_persona)
    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:consultar_cupos, id_albergue}, _from, estado) do
    respuesta = ServicioAlbergue.consultar_cupos(estado, id_albergue)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:consultar_ocupacion, id_albergue}, _from, estado) do
    respuesta = ServicioAlbergue.consultar_ocupacion(estado, id_albergue)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call(:reporte_ocupacion, _from, estado) do
    respuesta = ServicioAlbergue.reporte_ocupacion(estado)
    {:reply, respuesta, estado}
  end

  # ============================================================================
  # Persistencia
  # ============================================================================

  defp guardar_resultado({:ok, resultado, nuevo_estado}, estado_anterior) do
    case persistir(nuevo_estado) do
      :ok -> {:reply, {:ok, resultado}, nuevo_estado}
      {:error, motivo} -> {:reply, {:error, motivo}, estado_anterior}
    end
  end

  defp guardar_resultado({:error, motivo}, estado) do
    {:reply, {:error, motivo}, estado}
  end

  defp persistir(%EstadoPoblacion{} = estado) do
    GestorDatos.guardar_dominio(
      %{
        personas: estado.personas,
        familias: estado.familias,
        albergues: estado.albergues,
        registros_albergues: estado.registros_albergues
      },
      :poblacion
    )
  end
end
