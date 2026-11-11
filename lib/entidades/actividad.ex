defmodule Emergencia.Actividad do
  alias Emergencia.GeneradorID
  alias Emergencia.Reloj

  @enforce_keys [:id, :fecha, :descripcion, :operacion, :id_usuario]
  defstruct [:id, :fecha, :descripcion, :operacion, :id_usuario]

  @type t :: %__MODULE__{
          id: String.t(),
          fecha: DateTime.t(),
          descripcion: String.t(),
          operacion: String.t(),
          id_usuario: String.t()
        }

  @doc """
  Crea un nuevo registro de Actividad. Genera la fecha actual si no se proporciona en opciones.
  """
  def nueva(descripcion, operacion, id_usuario, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha, Reloj.ahora_local())
    operacion_texto = if is_atom(operacion), do: Atom.to_string(operacion), else: operacion

    cond do
      is_nil(descripcion) or is_nil(operacion) or is_nil(id_usuario) ->
        {:error, "Descripción, operación e ID de usuario son obligatorios"}

      not is_binary(descripcion) ->
        {:error, "La descripción debe ser texto"}

      not (is_atom(operacion) or is_binary(operacion)) ->
        {:error, "La operación debe ser texto o un átomo válido"}

      not is_binary(id_usuario) ->
        {:error, "El ID de usuario debe ser texto"}

      String.trim(descripcion) == "" or String.trim(operacion_texto) == "" ->
        {:error, "La descripción y la operación no pueden estar vacías"}

      String.trim(id_usuario) == "" ->
        {:error, "El ID de usuario no puede estar vacío"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           fecha: fecha,
           descripcion: descripcion,
           operacion: operacion_texto,
           id_usuario: id_usuario
         }}
    end
  end

  def a_map(%__MODULE__{} = actividad) do
    actividad
    |> Map.from_struct()
    |> Map.update!(:fecha, &DateTime.to_iso8601/1)
    |> Map.new(fn {campo, valor} -> {Atom.to_string(campo), valor} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha]),
         {:ok, actividad} <- construir(Map.put(attrs, :fecha, fecha)) do
      {:ok, actividad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de actividad inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La actividad debe ser un mapa válido"}

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
        else: {:error, "ID de actividad inválido"}
      )

  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha de actividad inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha de actividad inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de actividad: #{Exception.message(error)}"}
  end
end
