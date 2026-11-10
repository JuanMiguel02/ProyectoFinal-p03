defmodule Emergencia.MensajeDestinatario do
  alias Emergencia.GeneradorID

  @estados_permitidos [:pendiente, :entregado]

  @enforce_keys [:id_mensaje_destinatario, :codigo, :id_envio, :id_persona, :estado]
  defstruct [:id_mensaje_destinatario, :codigo, :id_envio, :id_persona, :fecha_entrega, :estado]

  @type estado_mensaje :: :pendiente | :entregado
  @type t :: %__MODULE__{
          id_mensaje_destinatario: String.t(),
          codigo: String.t(),
          id_envio: String.t(),
          id_persona: String.t(),
          fecha_entrega: DateTime.t() | nil,
          estado: estado_mensaje()
        }

  @doc """
  Crea un nuevo destinatario para un mensaje. Por defecto el estado es :pendiente.
  """
  def nuevo(id_envio, id_persona, estado \\ :pendiente, opciones \\ []) do
    codigo = Keyword.get(opciones, :codigo)
    fecha_entrega = Keyword.get(opciones, :fecha_entrega)

    cond do
      not texto_presente?(codigo) or not texto_presente?(id_envio) or
          not texto_presente?(id_persona) ->
        {:error, "Código, ID de envío e ID de persona son obligatorios"}

      estado not in @estados_permitidos ->
        {:error, "Estado :#{estado} inválido. Opciones: #{inspect(@estados_permitidos)}"}

      estado == :entregado and is_nil(fecha_entrega) ->
        # Regla de negocio: Si se crea como entregado, debe tener fecha de entrega
        {:error, "Un mensaje entregado debe tener una fecha de entrega"}

      true ->
        {:ok,
         %__MODULE__{
           id_mensaje_destinatario: GeneradorID.generar_uuid(),
           codigo: codigo,
           id_envio: id_envio,
           id_persona: id_persona,
           fecha_entrega: fecha_entrega,
           estado: estado
         }}
    end
  end

  @doc """
  Transiciona el estado de la notificación a :entregado y asigna el timestamp UTC actual.
  Si el mensaje ya figuraba como entregado, previene la sobrescritura del timestamp original.
  """
  def marcar_entregado(%__MODULE__{estado: :entregado}) do
    {:error, "La notificación ya se encuentra marcada como entregada"}
  end

  def marcar_entregado(%__MODULE__{} = registro) do
    {:ok, %{registro | estado: :entregado, fecha_entrega: DateTime.utc_now()}}
  end

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.update!(:fecha_entrega, fn
      %DateTime{} = fecha -> DateTime.to_iso8601(fecha)
      nil -> nil
    end)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    mapa = completar_codigo_legacy(mapa)
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         :ok <- validar_codigo(attrs[:codigo]),
         {:ok, estado} <- obtener_estado(attrs[:estado]),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha_entrega]),
         {:ok, entidad} <-
           construir(attrs |> Map.put(:estado, estado) |> Map.put(:fecha_entrega, fecha)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de destinatario inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El destinatario debe ser un mapa válido"}

  defp completar_codigo_legacy(mapa) do
    id = Map.get(mapa, "id_mensaje_destinatario", Map.get(mapa, :id_mensaje_destinatario))

    case Map.get(mapa, "codigo", Map.get(mapa, :codigo)) do
      codigo when is_binary(codigo) and codigo != "" ->
        mapa

      _ when is_binary(id) and id != "" ->
        Map.put(mapa, "codigo", "MDE-" <> String.upcase(id))

      _ ->
        mapa
    end
  end

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
      if(is_binary(attrs[:id_mensaje_destinatario]) and attrs[:id_mensaje_destinatario] != "",
        do: :ok,
        else: {:error, "ID del destinatario inválido"}
      )

  defp validar_codigo(codigo) when is_binary(codigo) and codigo != "", do: :ok
  defp validar_codigo(_), do: {:error, "Código del destinatario inválido"}

  defp texto_presente?(texto), do: is_binary(texto) and String.trim(texto) != ""

  defp obtener_estado(estado) when estado in @estados_permitidos, do: {:ok, estado}

  defp obtener_estado(estado) when is_binary(estado) do
    case Enum.find(@estados_permitidos, &(Atom.to_string(&1) == estado)) do
      nil -> {:error, "Estado de entrega inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_estado(_), do: {:error, "Estado de entrega inválido"}
  defp obtener_fecha(nil), do: {:ok, nil}
  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha de entrega inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha de entrega inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos del destinatario: #{Exception.message(error)}"}
  end
end
