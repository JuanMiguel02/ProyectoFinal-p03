defmodule Emergencia.EstadoMascotas do
  @moduledoc false
  defstruct reportes_mascotas: %{}, coincidencias_mascotas: %{}
end

defmodule Emergencia.MascotasServidor do
  use GenServer
  alias Emergencia.EstadoMascotas
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioMascotas

  # ============================================================================
  # API pública
  # ============================================================================
  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar_reporte(tipo, especie, color, tamano, id_zona, id_contacto, opciones \\ []) do
    GenServer.call(__MODULE__, {:registrar_reporte, tipo, especie, color, tamano, id_zona, id_contacto, opciones})
  end

  def buscar_coincidencias(id_reporte) do
    GenServer.call(__MODULE__, {:buscar_coincidencias, id_reporte})
  end

  def registrar_coincidencia(id_perdida, id_encontrada, id_usuario \\ "SISTEMA") do
    GenServer.call(__MODULE__, {:registrar_coincidencia, id_perdida, id_encontrada, id_usuario})
  end

  def resolver_reporte(id_reporte, id_usuario \\ "SISTEMA") do
    GenServer.call(__MODULE__, {:resolver_reporte, id_reporte, id_usuario})
  end

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
  def handle_call({:registrar_reporte, tipo, especie, color, tamano, id_zona, id_contacto, opciones}, _from, estado) do
    case ServicioMascotas.registrar_reporte(estado, tipo, especie, color, tamano, id_zona, id_contacto, opciones) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
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
