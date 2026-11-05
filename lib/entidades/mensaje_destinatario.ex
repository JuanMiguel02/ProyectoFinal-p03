defmodule Emergencia.MensajeDestinatario do
  @estados_permitidos [:pendiente, :entregado]

  @enforce_keys [:id_mensaje_destinatario, :id_envio, :id_persona, :estado]
  defstruct [:id_mensaje_destinatario, :id_envio, :id_persona, :fecha_entrega, :estado]

  @type estado_mensaje :: :pendiente | :entregado
  @type t :: %__MODULE__{
          id_mensaje_destinatario: String.t(),
          id_envio: String.t(),
          id_persona: String.t(),
          fecha_entrega: DateTime.t() | nil,
          estado: estado_mensaje()
        }

  @doc """
  Crea un nuevo destinatario para un mensaje. Por defecto el estado es :pendiente.
  """
  def nueva(id_md, id_envio, id_persona, estado \\ :pendiente, opciones \\ []) do
    fecha_entrega = Keyword.get(opciones, :fecha_entrega)

    cond do
      is_nil(id_md) or is_nil(id_envio) or is_nil(id_persona) ->
        {:error, "ID propio, ID de envío e ID de persona son obligatorios"}
      estado not in @estados_permitidos ->
        {:error, "Estado :#{estado} inválido. Opciones: #{inspect(@estados_permitidos)}"}
      estado == :entregado and is_nil(fecha_entrega) ->
        # Regla de negocio: Si se crea como entregado, debe tener fecha de entrega
        {:error, "Un mensaje entregado debe tener una fecha de entrega"}
      true ->
        {:ok, %__MODULE__{
          id_mensaje_destinatario: id_md,
          id_envio: id_envio,
          id_persona: id_persona,
          fecha_entrega: fecha_entrega,
          estado: estado
        }}
    end
  end

  def nueva!(id_md, id_envio, id_persona, estado \\ :pendiente, opciones \\ []) do
    case nueva(id_md, id_envio, id_persona, estado, opciones) do
      {:ok, mensaje_destinatario} -> mensaje_destinatario
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
