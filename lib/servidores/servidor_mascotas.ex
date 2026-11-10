defmodule Emergencia.EstadoMascotas do
  @moduledoc false
  defstruct reportes_mascotas: %{}, coincidencias_mascotas: %{}
end

defmodule Emergencia.MascotasServidor do
  use GenServer
  alias Emergencia.EstadoMascotas
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioMascotas
  alias Emergencia.NodoServidor

  # ============================================================================
  # API pública
  # ============================================================================
  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar_reporte(tipo, especie, color, tamano, id_zona, id_contacto, opciones \\ []) do
    NodoServidor.llamar(
      __MODULE__,
      {:registrar_reporte, tipo, especie, color, tamano, id_zona, id_contacto, opciones}
    )
  end

  def buscar_coincidencias(id_reporte) do
    NodoServidor.llamar(__MODULE__, {:buscar_coincidencias, id_reporte})
  end

  def registrar_coincidencia(id_perdida, id_encontrada, id_usuario \\ "SISTEMA") do
    NodoServidor.llamar(
      __MODULE__,
      {:registrar_coincidencia, id_perdida, id_encontrada, id_usuario}
    )
  end

  def resolver_reporte(id_reporte, id_usuario \\ "SISTEMA") do
    NodoServidor.llamar(__MODULE__, {:resolver_reporte, id_reporte, id_usuario})
  end

  def confirmar_coincidencia(id_coincidencia, id_usuario \\ "SISTEMA") do
    NodoServidor.llamar(__MODULE__, {:confirmar_coincidencia, id_coincidencia, id_usuario})
  end

  def listar_reportes, do: NodoServidor.llamar(__MODULE__, :listar_reportes)

  def listar_coincidencias, do: NodoServidor.llamar(__MODULE__, :listar_coincidencias)

  def buscar_reportes(criterios),
    do: NodoServidor.llamar(__MODULE__, {:buscar_reportes, criterios})

  # ============================================================================
  # Callbacks de GenServer
  # ============================================================================
  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:mascotas) do
      {:ok, datos} ->
        estado = %EstadoMascotas{
          reportes_mascotas: Map.get(datos, :reportes_mascotas, %{}),
          coincidencias_mascotas: Map.get(datos, :coincidencias_mascotas, %{})
        }

        {:ok, estado}

      {:error, motivo} ->
        {:stop, {:error_cargando_mascotas, motivo}}
    end
  end

  @impl true
  def handle_call(
        {:registrar_reporte, tipo, especie, color, tamano, id_zona, id_contacto, opciones},
        _from,
        estado
      ) do
    # 1. Ejecutamos la lógica pura (usamos 'nuevo' internamente en el struct)
    case ServicioMascotas.registrar_reporte(
           estado,
           tipo,
           especie,
           color,
           tamano,
           id_zona,
           id_contacto,
           opciones
         ) do
      {:ok, reporte, nuevo_estado} ->
        # 2. PROCESAMIENTO ASÍNCRONO SUPERVISADO
        # Lanza un proceso hijo independiente y supervisado
        Task.Supervisor.start_child(Emergencia.TaskSupervisor, fn ->
          IO.puts(
            "Iniciando búsqueda de coincidencias en background para el reporte: #{reporte.id}..."
          )

          ServicioMascotas.evaluar_coincidencias_background(reporte, nuevo_estado)
        end)

        # 3. Guardamos en disco y respondemos al usuario de inmediato
        procesar_persistencia(reporte, nuevo_estado, estado)

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:buscar_coincidencias, id_reporte}, _from, estado) do
    respuesta = ServicioMascotas.buscar_coincidencias(estado, id_reporte)
    {:reply, respuesta, estado}
  end

  @impl true
  def handle_call({:registrar_coincidencia, id_perdida, id_encontrada, id_usuario}, _from, estado) do
    case ServicioMascotas.registrar_coincidencia(estado, id_perdida, id_encontrada, id_usuario) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:resolver_reporte, id_reporte, id_usuario}, _from, estado) do
    case ServicioMascotas.resolver_reporte(estado, id_reporte, id_usuario) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:confirmar_coincidencia, id_coincidencia, id_usuario}, _from, estado) do
    case ServicioMascotas.confirmar_coincidencia(estado, id_coincidencia, id_usuario) do
      {:ok, resultado, nuevo_estado} ->
        procesar_persistencia(resultado, nuevo_estado, estado)

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(:listar_reportes, _from, estado) do
    {:reply, {:ok, Map.values(estado.reportes_mascotas)}, estado}
  end

  @impl true
  def handle_call(:listar_coincidencias, _from, estado) do
    {:reply, {:ok, Map.values(estado.coincidencias_mascotas)}, estado}
  end

  @impl true
  def handle_call({:buscar_reportes, criterios}, _from, estado) do
    {:reply, ServicioMascotas.buscar_reportes(estado, criterios), estado}
  end

  # ============================================================================
  # Persistencia
  # ============================================================================
  defp procesar_persistencia(resultado, nuevo_estado, estado_anterior) do
    case persistir(nuevo_estado) do
      :ok -> {:reply, {:ok, resultado}, nuevo_estado}
      {:error, motivo} -> {:reply, {:error, {:error_persistencia, motivo}}, estado_anterior}
    end
  end

  defp persistir(%EstadoMascotas{} = estado) do
    GestorDatos.guardar_dominio(
      %{
        reportes_mascotas: estado.reportes_mascotas,
        coincidencias_mascotas: estado.coincidencias_mascotas
      },
      :mascotas
    )
  end
end
