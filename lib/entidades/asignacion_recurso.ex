defmodule Emergencia.AsignacionRecurso do
  alias Emergencia.GeneradorID

  @estados_permitidos [:asignado, :entregado, :cancelado]

  @enforce_keys [:id, :id_necesidad, :cantidad_asignada, :fecha_asignada, :estado]
  defstruct [
    :id,
    :id_necesidad,
    :id_recurso,
    :ubicacion,
    :cantidad_asignada,
    :fecha_asignada,
    :estado
  ]

  @type estado_asignacion :: :asignado | :entregado | :cancelado
  @type t :: %__MODULE__{
          id: String.t(),
          id_necesidad: String.t(),
          id_recurso: String.t() | nil,
          ubicacion: String.t() | nil,
          cantidad_asignada: pos_integer(),
          fecha_asignada: DateTime.t(),
          estado: estado_asignacion()
        }

  def nueva_directa(id_necesidad, id_recurso, ubicacion, cantidad, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha_asignada, DateTime.utc_now())
    estado = Keyword.get(opciones, :estado, :asignado)

    cond do
      is_nil(id_necesidad) or is_nil(id_recurso) or is_nil(ubicacion) ->
        {:error, "Necesidad, recurso y ubicación son obligatorios"}

      not is_integer(cantidad) or cantidad <= 0 ->
        {:error, "La cantidad asignada debe ser un número entero mayor a cero"}

      estado not in @estados_permitidos ->
        {:error, "Estado :#{estado} inválido. Opciones: #{inspect(@estados_permitidos)}"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           id_necesidad: id_necesidad,
           id_recurso: id_recurso,
           ubicacion: ubicacion,
           cantidad_asignada: cantidad,
           fecha_asignada: fecha,
           estado: estado
         }}
    end
  end

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.update!(:fecha_asignada, &DateTime.to_iso8601/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, estado} <- obtener_estado(attrs[:estado]),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha_asignada]),
         {:ok, entidad} <-
           construir(attrs |> Map.put(:estado, estado) |> Map.put(:fecha_asignada, fecha)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de asignación inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La asignación debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_id(attrs),
    do:
      if(is_binary(attrs[:id]) and attrs[:id] != "",
        do: :ok,
        else: {:error, "ID de asignación inválido"}
      )

  defp obtener_estado(estado) when estado in @estados_permitidos, do: {:ok, estado}

  defp obtener_estado(estado) when is_binary(estado) do
    case Enum.find(@estados_permitidos, &(Atom.to_string(&1) == estado)) do
      nil -> {:error, "Estado de asignación inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_estado(_), do: {:error, "Estado de asignación inválido"}
  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha de asignación inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha de asignación inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de asignación: #{Exception.message(error)}"}
  end
end
