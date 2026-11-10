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
    AsignacionRecurso,
    EstadoRecursos,
    GestorDatos,
    MovimientoRecurso,
    Necesidad,
    Recurso
  }

  alias Emergencia.Almacenamiento.JSON
  alias Emergencia.Servicios.ServicioRecursos

  @archivo "logistica.json"

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar_necesidad(tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    GenServer.call(
      __MODULE__,
      {:registrar_necesidad, tipo, cantidad, id_zona, prioridad, opciones}
    )
  end

  def listar_necesidades, do: GenServer.call(__MODULE__, :listar_necesidades)

  def listar_necesidades_ordenadas,
    do: GenServer.call(__MODULE__, :listar_necesidades_ordenadas)

  def registrar_recurso(nombre, cantidad, unidad, ubicacion) do
    GenServer.call(__MODULE__, {:registrar_recurso, nombre, cantidad, unidad, ubicacion})
  end

  def listar_recursos(filtros \\ %{}),
    do: GenServer.call(__MODULE__, {:listar_recursos, filtros})

  def listar_todos_recursos, do: GenServer.call(__MODULE__, :listar_todos_recursos)

  def asignar_recurso_directo(id_necesidad, codigo_recurso, cantidad, _id_usuario \\ "SISTEMA") do
    GenServer.call(__MODULE__, {:asignar_recurso, id_necesidad, codigo_recurso, cantidad})
  end

  def transferir_recurso(codigo, origen, destino, cantidad) do
    GenServer.call(__MODULE__, {:transferir_recurso, codigo, origen, destino, cantidad})
  end

  def calcular_stock_global(codigo_recurso) do
    GenServer.call(__MODULE__, {:calcular_stock_global, codigo_recurso})
  end

  def listar_centros_acopio, do: Emergencia.TerritorioServidor.listar_centros_acopio()

  @impl true
  def init(_opciones) do
    case cargar_estado() do
      {:ok, estado} -> {:ok, estado}
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
    case JSON.cargar(@archivo) do
      {:ok, mapa} when is_map(mapa) ->
        reconstruir_estado(mapa)

      {:ok, []} ->
        migrar_datos_anteriores()

      {:ok, otro} ->
        {:error,
         "El archivo #{@archivo} debe contener un objeto JSON, se recibió #{inspect(otro)}"}

      error ->
        error
    end
  end

  defp reconstruir_estado(mapa) do
    with {:ok, recursos} <- reconstruir_coleccion(Map.get(mapa, "recursos", []), Recurso),
         {:ok, movimientos} <-
           reconstruir_coleccion(Map.get(mapa, "movimientos", []), MovimientoRecurso),
         {:ok, existencias} <- reconstruir_existencias(Map.get(mapa, "existencias", [])),
         {:ok, necesidades} <- cargar_o_migrar_necesidades(mapa),
         {:ok, asignaciones} <-
           reconstruir_coleccion(Map.get(mapa, "asignaciones", []), AsignacionRecurso) do
      {:ok,
       %EstadoRecursos{
         recursos: Map.new(recursos, &{&1.id, &1}),
         existencias: existencias,
         movimientos: Map.new(movimientos, &{&1.id, &1}),
         necesidades: Map.new(necesidades, &{&1.id, &1}),
         asignaciones: Map.new(asignaciones, &{&1.id, &1})
       }}
    end
  end

  defp cargar_o_migrar_necesidades(mapa) do
    case Map.fetch(mapa, "necesidades") do
      {:ok, lista} -> reconstruir_coleccion(lista, Necesidad)
      :error -> GestorDatos.cargar_coleccion("necesidades.json", Necesidad, :id)
    end
  end

  defp migrar_datos_anteriores do
    with {:ok, recursos} <- GestorDatos.cargar_coleccion("recursos.json", Recurso, :id),
         {:ok, necesidades} <- GestorDatos.cargar_coleccion("necesidades.json", Necesidad, :id) do
      {:ok,
       %EstadoRecursos{
         recursos: recursos,
         existencias: %{},
         movimientos: %{},
         necesidades: necesidades,
         asignaciones: %{}
       }}
    end
  end

  defp reconstruir_coleccion(lista, modulo) when is_list(lista) do
    Enum.reduce_while(lista, {:ok, []}, fn mapa, {:ok, acc} ->
      case apply(modulo, :desde_map, [mapa]) do
        {:ok, entidad} -> {:cont, {:ok, [entidad | acc]}}
        {:error, motivo} -> {:halt, {:error, motivo}}
      end
    end)
    |> case do
      {:ok, entidades} -> {:ok, Enum.reverse(entidades)}
      error -> error
    end
  end

  defp reconstruir_coleccion(_, _), do: {:error, "La colección debe ser una lista"}

  defp reconstruir_existencias(lista) when is_list(lista) do
    Enum.reduce_while(lista, {:ok, %{}}, fn
      %{"codigo_recurso" => codigo, "ubicacion" => ubicacion, "cantidad" => cantidad}, {:ok, acc}
      when is_binary(codigo) and is_binary(ubicacion) and is_integer(cantidad) and cantidad >= 0 ->
        {:cont, {:ok, Map.put(acc, {codigo, ubicacion}, cantidad)}}

      _, _ ->
        {:halt, {:error, "Registro de existencias inválido"}}
    end)
  end

  defp reconstruir_existencias(_), do: {:error, "Las existencias deben ser una lista"}

  defp persistir(%EstadoRecursos{} = estado) do
    JSON.guardar(@archivo, %{
      "recursos" => Enum.map(estado.recursos, fn {_id, recurso} -> Recurso.a_map(recurso) end),
      "existencias" =>
        Enum.map(estado.existencias, fn {{codigo, ubicacion}, cantidad} ->
          %{"codigo_recurso" => codigo, "ubicacion" => ubicacion, "cantidad" => cantidad}
        end),
      "movimientos" =>
        Enum.map(estado.movimientos, fn {_id, movimiento} ->
          MovimientoRecurso.a_map(movimiento)
        end),
      "necesidades" =>
        Enum.map(estado.necesidades, fn {_id, necesidad} -> Necesidad.a_map(necesidad) end),
      "asignaciones" =>
        Enum.map(estado.asignaciones, fn {_id, asignacion} ->
          AsignacionRecurso.a_map(asignacion)
        end)
    })
  end
end
