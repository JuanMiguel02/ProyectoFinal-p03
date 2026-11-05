defmodule Emergencia.Sector do
  @niveles_permitidos [:bajo, :medio, :alto, :critico]

  @enforce_keys [:id, :nombre, :nivel_afectacion, :personas_afectadas]
  defstruct [:id, :nombre, :nivel_afectacion, :personas_afectadas, puntos_atencion: []]

  @type nivel_afectacion :: :bajo | :medio | :alto | :critico
  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          nivel_afectacion: nivel_afectacion(),
          personas_afectadas: non_neg_integer(),
          puntos_atencion: list()
        }

  def nueva(id, nombre, nivel, personas) do
    cond do
      is_nil(id) or is_nil(nombre) ->
        {:error, "El ID y el nombre son obligatorios"}
      nivel not in @niveles_permitidos ->
        {:error, "Nivel de afectación :#{nivel} inválido"}
      personas < 0 ->
        {:error, "La cantidad de personas afectadas no puede ser negativa"}
      true ->
        {:ok, %__MODULE__{
          id: id,
          nombre: nombre,
          nivel_afectacion: nivel,
          personas_afectadas: personas,
          puntos_atencion: []
        }}
    end
  end

  def nueva!(id, nombre, nivel, personas) do
    case nueva(id, nombre, nivel, personas) do
      {:ok, sector} -> sector
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
