defmodule Emergencia.Familia do
  @enforce_keys [:id, :nombre]
  defstruct [:id, :nombre]

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t()
        }

  @doc """
  Crea una nueva Familia de forma segura.
  """
  def nueva(id, nombre) do
    cond do
      is_nil(id) or is_nil(nombre) ->
        {:error, "El ID y el nombre son obligatorios"}
      String.trim(nombre) == "" ->
        {:error, "El nombre de la familia no puede estar vacío"}
      true ->
        {:ok, %__MODULE__{
          id: id,
          nombre: nombre
        }}
    end
  end

  @doc """
  Crea una nueva Familia o lanza excepción si los datos son inválidos.
  """
  def nueva!(id, nombre) do
    case nueva(id, nombre) do
      {:ok, familia} -> familia
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
