defmodule Emergencia.Actividad do
  alias Emergencia.GeneradorID

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
    fecha = Keyword.get(opciones, :fecha, DateTime.utc_now())

    cond do
      is_nil(descripcion) or is_nil(operacion) or is_nil(id_usuario) ->
        {:error, "Descripción, operación e ID de usuario son obligatorios"}

      String.trim(descripcion) == "" or String.trim(operacion) == "" ->
        {:error, "La descripción y la operación no pueden estar vacías"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           fecha: fecha,
           descripcion: descripcion,
           operacion: operacion,
           id_usuario: id_usuario
         }}
    end
  end

  @doc """
  Crea una nueva Actividad o lanza un ArgumentError en caso de fallo.
  """
  def nueva!(descripcion, operacion, id_usuario, opciones \\ []) do
    case nueva(descripcion, operacion, id_usuario, opciones) do
      {:ok, actividad} -> actividad
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
