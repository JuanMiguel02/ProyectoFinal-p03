defmodule Emergencia.Sector do
  alias Emergencia.GeneradorID

  @niveles_permitidos [:bajo, :medio, :alto, :critico]

  @enforce_keys [:id, :codigo_sector, :nombre, :nivel_afectacion, :personas_afectadas]
  defstruct [
    :id,
    :codigo_sector,
    :nombre,
    :nivel_afectacion,
    :personas_afectadas,
    puntos_atencion: []
  ]

  @type nivel_afectacion :: :bajo | :medio | :alto | :critico
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_sector: String.t(),
          nombre: String.t(),
          nivel_afectacion: nivel_afectacion(),
          personas_afectadas: non_neg_integer(),
          puntos_atencion: list()
        }

  def nueva(nombre, nivel, personas) do
    cond do
      is_nil(nombre) ->
        {:error, "El nombre es obligatorio"}

      nivel not in @niveles_permitidos ->
        {:error, "Nivel de afectación :#{nivel} inválido"}

      personas < 0 ->
        {:error, "La cantidad de personas afectadas no puede ser negativa"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_sector: GeneradorID.generar("SEC"),
           nombre: nombre,
           nivel_afectacion: nivel,
           personas_afectadas: personas,
           puntos_atencion: []
         }}
    end
  end

  def nueva!(nombre, nivel, personas) do
    case nueva(nombre, nivel, personas) do
      {:ok, sector} -> sector
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
