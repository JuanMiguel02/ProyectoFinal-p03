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
  alias Emergencia.Servicios.ServicioPersonas
  alias Emergencia.Servicios.ServicioFamilia
  alias Emergencia.NodoServidor

  # ============================================================================
  # API pública
  # ============================================================================

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  # ----------------------------------------------------------------------------
  # Albergues
  # ----------------------------------------------------------------------------

  def registrar_albergue(nombre, id_zona, capacidad_maxima) do
    NodoServidor.llamar(__MODULE__, {:registrar_albergue, nombre, id_zona, capacidad_maxima})
  end

  def ingresar_persona(id_persona, id_albergue) do
    NodoServidor.llamar(__MODULE__, {:ingresar_persona, id_persona, id_albergue})
  end

  def registrar_salida(id_persona, nuevo_estado_persona \\ :localizada) do
    NodoServidor.llamar(__MODULE__, {:registrar_salida, id_persona, nuevo_estado_persona})
  end

  def consultar_cupos(id_albergue) do
    NodoServidor.llamar(__MODULE__, {:consultar_cupos, id_albergue})
  end

  def consultar_ocupacion(id_albergue) do
    NodoServidor.llamar(__MODULE__, {:consultar_ocupacion, id_albergue})
  end

  def reporte_ocupacion do
    NodoServidor.llamar(__MODULE__, :reporte_ocupacion)
  end

  def listar_albergues do
    NodoServidor.llamar(__MODULE__, :listar_albergues)
  end

  def buscar_albergue(identificador) do
    NodoServidor.llamar(__MODULE__, {:buscar_albergue, identificador})
  end

  # ============================================================================
  # Personas
  # ============================================================================

  def registrar_persona(nombre, documento, id_zona, estado_persona, opciones \\ []) do
    NodoServidor.llamar(
      __MODULE__,
      {:registrar_persona, nombre, documento, id_zona, estado_persona, opciones}
    )
  end

  def cambiar_estado_persona(id_persona, nuevo_estado) do
    NodoServidor.llamar(__MODULE__, {:cambiar_estado_persona, id_persona, nuevo_estado})
  end

  def buscar_personas(criterios) do
    NodoServidor.llamar(__MODULE__, {:buscar_personas, criterios})
  end

  def consultar_historial_persona(documento_o_id) do
    NodoServidor.llamar(__MODULE__, {:consultar_historial_persona, documento_o_id})
  end

  def asignar_familia(id_persona, id_familia) do
    NodoServidor.llamar(__MODULE__, {:asignar_familia, id_persona, id_familia})
  end

  def consultar_persona(id_persona) do
    NodoServidor.llamar(__MODULE__, {:consultar_persona, id_persona})
  end

  # ============================================================================
  # Familias
  # ============================================================================

  def registrar_familia(nombre) do
    NodoServidor.llamar(__MODULE__, {:registrar_familia, nombre})
  end

  def buscar_familia(id_o_codigo) do
    NodoServidor.llamar(__MODULE__, {:buscar_familia, id_o_codigo})
  end

  def listar_familias do
    NodoServidor.llamar(__MODULE__, :listar_familias)
  end

  def consultar_integrantes(id_o_codigo_familia) do
    NodoServidor.llamar(__MODULE__, {:consultar_integrantes, id_o_codigo_familia})
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
  def handle_call({:registrar_albergue, nombre, id_zona, capacidad_maxima}, _from, estado) do
    resultado = ServicioAlbergue.registrar(estado, nombre, id_zona, capacidad_maxima)
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

  @impl true
  def handle_call(:listar_albergues, _from, estado) do
    respuesta = ServicioAlbergue.listar_albergues(estado)

    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:buscar_albergue, identificador}, _from, estado) do
    respuesta = ServicioAlbergue.buscar_albergue(estado, identificador)

    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call(
        {:registrar_persona, nombre, documento, id_zona, estado_persona, opciones},
        _from,
        estado
      ) do
    resultado =
      ServicioPersonas.registrar(estado, nombre, documento, id_zona, estado_persona, opciones)

    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:cambiar_estado_persona, id_persona, nuevo_estado}, _from, estado) do
    resultado = ServicioPersonas.cambiar_estado(estado, id_persona, nuevo_estado)
    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:buscar_personas, criterios}, _from, estado) do
    respuesta = ServicioPersonas.buscar_personas(estado, criterios)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:consultar_historial_persona, documento_o_id}, _from, estado) do
    respuesta = ServicioPersonas.consultar_historial(estado, documento_o_id)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:consultar_persona, id_persona}, _from, estado) do
    respuesta = ServicioPersonas.consultar_persona(estado.personas, id_persona)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:asignar_familia, id_persona, id_familia}, _from, estado) do
    resultado = ServicioPersonas.asignar_a_familia(estado, id_persona, id_familia)
    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:registrar_familia, nombre}, _from, estado) do
    resultado = ServicioFamilia.registrar(estado, nombre)
    guardar_resultado(resultado, estado)
  end

  @impl true
  def handle_call({:buscar_familia, id_o_codigo}, _from, estado) do
    respuesta = ServicioFamilia.buscar_familia(estado, id_o_codigo)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call(:listar_familias, _from, estado) do
    respuesta = ServicioFamilia.listar_familias(estado)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:consultar_integrantes, id_o_codigo_familia}, _from, estado) do
    respuesta = ServicioFamilia.consultar_integrantes(estado, id_o_codigo_familia)
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
