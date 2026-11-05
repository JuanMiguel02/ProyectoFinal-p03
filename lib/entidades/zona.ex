defmodule Emergencia.Zona do
  @niveles_permitidos [:bajo, :medio, :alto, :critico]

  @enforce_keys [:id, :nombre, :nivel_afectacion, :personas_estimadas]
  defstruct [:id, :nombre, :nivel_afectacion, :personas_estimadas, sectores: []]

  @type nivel_afectacion :: :bajo | :medio | :alto | :critico
  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          nivel_afectacion: nivel_afectacion(),
          personas_estimadas: non_neg_integer(),
          sectores: list()
        }

  def nueva(id, nombre, nivel, personas) do
    cond do
      is_nil(id) or is_nil(nombre) ->
        {:error, "El ID y el nombre son obligatorios"}
      nivel not in @niveles_permitidos ->
        {:error, "Nivel de afectación :#{nivel} inválido"}
      personas < 0 ->
        {:error, "Las personas estimadas no pueden ser negativas"}
      true ->
        {:ok, %__MODULE__{
          id: id,
          nombre: nombre,
          nivel_afectacion: nivel,
          personas_estimadas: personas,
          sectores: []
        }}
    end
  end

  def nueva!(id, nombre, nivel, personas) do
    case nueva(id, nombre, nivel, personas) do
      {:ok, zona} -> zona
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
