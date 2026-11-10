defmodule Emergencia.EstadoRecursos do
  @moduledoc false

  defstruct recursos: %{},
            existencias: %{},
            movimientos: %{},
            necesidades: %{},
            asignaciones: %{}
end

defmodule Emergencia.RecursosServidor do
  use GenServer

  alias Emergencia.{
    EstadoRecursos,
    GestorDatos
  }

  alias Emergencia.Servicios.ServicioRecursos
  alias Emergencia.NodoServidor

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar_necesidad(tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    NodoServidor.llamar(
      __MODULE__,
      {:registrar_necesidad, tipo, cantidad, id_zona, prioridad, opciones}
    )
  end

  def listar_necesidades, do: NodoServidor.llamar(__MODULE__, :listar_necesidades)

  def listar_necesidades_ordenadas,
    do: NodoServidor.llamar(__MODULE__, :listar_necesidades_ordenadas)

  def registrar_recurso(nombre, cantidad, unidad, ubicacion) do
    NodoServidor.llamar(__MODULE__, {:registrar_recurso, nombre, cantidad, unidad, ubicacion})
  end

  def listar_recursos(filtros \\ %{}),
    do: NodoServidor.llamar(__MODULE__, {:listar_recursos, filtros})

  def listar_todos_recursos, do: NodoServidor.llamar(__MODULE__, :listar_todos_recursos)

  def asignar_recurso_directo(id_necesidad, codigo_recurso, cantidad, _id_usuario \\ "SISTEMA") do
    NodoServidor.llamar(__MODULE__, {:asignar_recurso, id_necesidad, codigo_recurso, cantidad})
  end

  def transferir_recurso(codigo, origen, destino, cantidad) do
    NodoServidor.llamar(__MODULE__, {:transferir_recurso, codigo, origen, destino, cantidad})
  end

  def calcular_stock_global(codigo_recurso) do
    NodoServidor.llamar(__MODULE__, {:calcular_stock_global, codigo_recurso})
  end

  def listar_centros_acopio, do: Emergencia.TerritorioServidor.listar_centros_acopio()

  @impl true
  def init(_opciones) do
    case cargar_estado() do
      {:ok, datos} -> {:ok, struct(EstadoRecursos, datos)}
      {:error, motivo} -> {:stop, {:error_cargando_recursos, motivo}}
    end
  end

  @impl true
  def handle_call(
        {:registrar_necesidad, tipo, cantidad, id_zona, prioridad, opciones},
        _from,
        estado
      ) do
    ejecutar_y_persistir(estado, fn ->
      ServicioRecursos.registrar_necesidad(estado, tipo, cantidad, id_zona, prioridad, opciones)
    end)
  end

  def handle_call(:listar_necesidades, _from, estado) do
    {:reply, {:ok, Map.values(estado.necesidades)}, estado}
  end

  def handle_call(:listar_necesidades_ordenadas, _from, estado) do
    {:reply, ServicioRecursos.listar_necesidades_ordenadas(estado), estado}
  end

  def handle_call(
        {:registrar_recurso, nombre, cantidad, unidad, ubicacion},
        _from,
        estado
      ) do
    ejecutar_y_persistir(estado, fn ->
      ServicioRecursos.registrar_recurso(estado, nombre, cantidad, unidad, ubicacion)
    end)
  end

  def handle_call({:listar_recursos, filtros}, _from, estado) do
    {:reply, ServicioRecursos.listar_recursos(estado, filtros), estado}
  end

  def handle_call(:listar_todos_recursos, _from, estado) do
    {:reply, ServicioRecursos.listar_todos_recursos(estado), estado}
  end

  def handle_call({:asignar_recurso, id_necesidad, codigo_recurso, cantidad}, _from, estado) do
    ejecutar_y_persistir(estado, fn ->
      ServicioRecursos.asignar_a_necesidad(estado, id_necesidad, codigo_recurso, cantidad)
    end)
  end

  def handle_call({:transferir_recurso, codigo, origen, destino, cantidad}, _from, estado) do
    ejecutar_y_persistir(estado, fn ->
      ServicioRecursos.transferir_recurso(estado, codigo, origen, destino, cantidad)
    end)
  end

  def handle_call({:calcular_stock_global, codigo_recurso}, _from, estado) do
    {:reply, ServicioRecursos.calcular_stock_global(estado, codigo_recurso), estado}
  end

  defp ejecutar_y_persistir(estado, operacion) do
    case operacion.() do
      {:ok, resultado, nuevo_estado} ->
        case persistir(nuevo_estado) do
          :ok -> {:reply, {:ok, resultado}, nuevo_estado}
          {:error, motivo} -> {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  defp cargar_estado do
    GestorDatos.cargar_estado_recursos()
  end

  defp persistir(%EstadoRecursos{} = estado) do
    GestorDatos.guardar_estado_recursos(estado)
  end
end
