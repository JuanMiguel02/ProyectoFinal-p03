defmodule Emergencia.Zona do
  alias Emergencia.GeneradorID

  @niveles_permitidos [:bajo, :medio, :alto, :critico]

  @enforce_keys [:id, :codigo_zona, :nombre, :nivel_afectacion, :personas_estimadas]
  defstruct [:id, :codigo_zona, :nombre, :nivel_afectacion, :personas_estimadas, sectores: []]

  @type nivel_afectacion :: :bajo | :medio | :alto | :critico
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_zona: String.t(),
          nombre: String.t(),
          nivel_afectacion: nivel_afectacion(),
          personas_estimadas: non_neg_integer(),
          sectores: list()
        }

  def nueva(nombre, nivel, personas) do
    cond do
      is_nil(nombre) ->
        {:error, "El nombre es obligatorio"}

      nivel not in @niveles_permitidos ->
        {:error, "Nivel de afectación :#{nivel} inválido"}

      personas < 0 ->
        {:error, "Las personas estimadas no pueden ser negativas"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_zona: GeneradorID.generar("ZON"),
           nombre: nombre,
           nivel_afectacion: nivel,
           personas_estimadas: personas,
           sectores: []
         }}
    end
  end

  def nueva!(nombre, nivel, personas) do
    case nueva(nombre, nivel, personas) do
      {:ok, zona} -> zona
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
