defmodule Emergencia.Mensaje do
  alias Emergencia.GeneradorID
  alias Emergencia.Reloj

  @enforce_keys [:id_envio, :id_remitente, :fecha, :contenido]
  defstruct [:id_envio, :id_remitente, :fecha, :contenido]

  @type t :: %__MODULE__{
          id_envio: String.t(),
          id_remitente: String.t(),
          fecha: DateTime.t(),
          contenido: String.t()
        }

  @doc """
  Crea un nuevo Mensaje. Genera la fecha actual automáticamente si no se especifica.
  """
  def nuevo(id_remitente, contenido, opciones \\ []) do
    # Extraemos la fecha de las opciones o asignamos el momento actual por defecto
    fecha = Keyword.get(opciones, :fecha, Reloj.ahora_local())

    cond do
      is_nil(id_remitente) or is_nil(contenido) ->
        {:error, "Remitente y contenido son obligatorios"}

      String.trim(contenido) == "" ->
        {:error, "El contenido del mensaje no puede estar vacío"}

      true ->
        {:ok,
         %__MODULE__{
           id_envio: GeneradorID.generar_uuid(),
           id_remitente: id_remitente,
           fecha: fecha,
           contenido: contenido
         }}
    end
  end

  def a_map(%__MODULE__{} = mensaje) do
    mensaje
    |> Map.from_struct()
    |> Map.update!(:fecha, &DateTime.to_iso8601/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha]),
         {:ok, mensaje} <- construir(Map.put(attrs, :fecha, fecha)) do
      {:ok, mensaje}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de mensaje inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El mensaje debe ser un mapa válido"}

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
      if(is_binary(attrs[:id_envio]) and attrs[:id_envio] != "",
        do: :ok,
        else: {:error, "ID del envío inválido"}
      )

  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha del mensaje inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha del mensaje inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos del mensaje: #{Exception.message(error)}"}
  end
end
