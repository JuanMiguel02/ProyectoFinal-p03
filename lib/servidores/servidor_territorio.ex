defmodule Emergencia.EstadoTerritorio do
  @moduledoc false
  defstruct zonas: %{}, sectores: %{}, centros_acopio: %{}
end

defmodule Emergencia.TerritorioServidor do
  use GenServer
  alias Emergencia.EstadoTerritorio
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioTerritorio

  # ============================================================================
  # API pública
  # ============================================================================
  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar_zona(nombre, nivel, personas_estimadas, id_usuario \\ "SISTEMA") do
    GenServer.call(__MODULE__, {:registrar_zona, nombre, nivel, personas_estimadas, id_usuario})
  end

  def registrar_sector(id_zona, nombre, nivel, personas_afectadas, id_usuario \\ "SISTEMA") do
    GenServer.call(__MODULE__, {:registrar_sector, id_zona, nombre, nivel, personas_afectadas, id_usuario})
  end

  def estadisticas_zona(id_zona) do
    GenServer.call(__MODULE__, {:estadisticas_zona, id_zona})
  end

  # ============================================================================
  # Callbacks de GenServer
  # ============================================================================
  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:territorio) do
      {:ok, datos} ->
        estado = %EstadoTerritorio{
          zonas: Map.get(datos, :zonas, %{}),
          sectores: Map.get(datos, :sectores, %{}),
          centros_acopio: Map.get(datos, :centros_acopio, %{})
        }
        {:ok, estado}

      {:error, motivo} ->
        {:stop, {:error_cargando_territorio, motivo}}
    end
  end

  @impl true
  def handle_call({:registrar_zona, nombre, nivel, personas, id_usuario}, _from, estado) do
    case ServicioTerritorio.registrar_zona(estado, nombre, nivel, personas, id_usuario) do
      {:ok, resultado, nuevo_estado} ->
        case persistir(nuevo_estado) do
          :ok -> {:reply, {:ok, resultado}, nuevo_estado}
          {:error, motivo} -> {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end
      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:registrar_sector, id_zona, nombre, nivel, personas, id_usuario}, _from, estado) do
    case ServicioTerritorio.registrar_sector(estado, id_zona, nombre, nivel, personas, id_usuario) do
      {:ok, resultado, nuevo_estado} ->
        case persistir(nuevo_estado) do
          :ok -> {:reply, {:ok, resultado}, nuevo_estado}
          {:error, motivo} -> {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end
      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:estadisticas_zona, id_zona}, _from, estado) do
    respuesta = ServicioTerritorio.estadisticas_zona(estado, id_zona)
    {:reply, respuesta, estado}
  end

  # ============================================================================
  # Persistencia
  # ============================================================================
  defp persistir(%EstadoTerritorio{} = estado) do
    GestorDatos.guardar_dominio(
      %{
        zonas: estado.zonas,
        sectores: estado.sectores,
        centros_acopio: estado.centros_acopio
      },
      :territorio
    )
  end
end
