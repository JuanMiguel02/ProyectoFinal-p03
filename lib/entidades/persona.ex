defmodule Emergencia.Persona do
  alias Emergencia.GeneradorID

  @estados_permitidos [
    :sin_informacion,
    :reportada,
    :localizada,
    :trasladada,
    :en_albergue,
    :reunificada
  ]

  @enforce_keys [:id, :codigo_persona, :nombre, :documento, :id_zona, :estado]
  defstruct [
    :id,
    :codigo_persona,
    :nombre,
    :documento,
    :dato_referencia,
    :edad,
    :id_zona,
    :id_familia,
    :estado,
    historial_estados: []
  ]

  @type estado_persona ::
          :sin_informacion | :reportada | :localizada | :trasladada | :en_albergue | :reunificada
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_persona: String.t(),
          nombre: String.t(),
          documento: String.t(),
          dato_referencia: String.t() | nil,
          edad: non_neg_integer() | nil,
          id_zona: String.t(),
          id_familia: String.t() | nil,
          estado: estado_persona(),
          historial_estados: list()
        }

  def nueva(nombre, documento, id_zona, estado, opciones \\ []) do
    edad = Keyword.get(opciones, :edad)
    dato_ref = Keyword.get(opciones, :dato_referencia)
    id_fam = Keyword.get(opciones, :id_familia)

    cond do
      is_nil(nombre) or is_nil(documento) or is_nil(id_zona) ->
        {:error, "Nombre, documento y zona son obligatorios"}

      estado not in @estados_permitidos ->
        {:error, "Estado inválido. Opciones: #{inspect(@estados_permitidos)}"}

      not is_nil(edad) and (not is_integer(edad) or edad < 0) ->
        {:error, "La edad debe ser un número entero no negativo"}

      true ->
        historial_inicial = [{estado, DateTime.utc_now()}]

        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_persona: GeneradorID.generar("PER"),
           nombre: nombre,
           documento: documento,
           dato_referencia: dato_ref,
           edad: edad,
           id_zona: id_zona,
           id_familia: id_fam,
           estado: estado,
           historial_estados: historial_inicial
         }}
    end
  end

  def nueva!(nombre, documento, id_zona, estado, opciones \\ []) do
    case nueva(nombre, documento, id_zona, estado, opciones) do
      {:ok, persona} -> persona
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
