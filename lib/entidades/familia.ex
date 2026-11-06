defmodule Emergencia.Familia do
  alias Emergencia.GeneradorID

  @enforce_keys [:id, :codigo_familia, :nombre]
  defstruct [:id, :codigo_familia, :nombre]

  @type t :: %__MODULE__{
          id: String.t(),
          codigo_familia: String.t(),
          nombre: String.t()
        }

  @doc """
  Crea una nueva Familia de forma segura.
  """
  def nueva(nombre) do
    cond do
      is_nil(nombre) ->
        {:error, "El nombre es obligatorio"}

      String.trim(nombre) == "" ->
        {:error, "El nombre de la familia no puede estar vacío"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_familia: GeneradorID.generar("FAM"),
           nombre: nombre
         }}
    end
  end

  @doc """
  Crea una nueva Familia o lanza excepción si los datos son inválidos.
  """
  def nueva!(nombre) do
    case nueva(nombre) do
      {:ok, familia} -> familia
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
