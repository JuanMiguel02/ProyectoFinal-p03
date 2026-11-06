defmodule Emergencia.Mensaje do
  alias Emergencia.GeneradorID

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
    fecha = Keyword.get(opciones, :fecha, DateTime.utc_now())

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

  def nuevo!(id_remitente, contenido, opciones \\ []) do
    case nuevo(id_remitente, contenido, opciones) do
      {:ok, mensaje} -> mensaje
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
