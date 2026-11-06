defmodule Emergencia.PuntoAtencion do
  alias Emergencia.GeneradorID

  @tipos_permitidos [:medico, :logistico, :distribucion]

  @enforce_keys [:id, :codigo_punto_atencion, :nombre, :tipo, :ubicacion]
  defstruct [:id, :codigo_punto_atencion, :nombre, :descripcion, :tipo, :ubicacion]

  @type tipo_punto :: :medico | :logistico | :distribucion
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_punto_atencion: String.t(),
          nombre: String.t(),
          descripcion: String.t() | nil,
          tipo: tipo_punto(),
          ubicacion: String.t()
        }

  def nueva(nombre, tipo, ubicacion, descripcion \\ nil) do
    cond do
      is_nil(nombre) or is_nil(ubicacion) ->
        {:error, "Nombre y ubicación son obligatorios"}

      tipo not in @tipos_permitidos ->
        {:error, "El tipo de punto :#{tipo} no es válido"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_punto_atencion: GeneradorID.generar("PAT"),
           nombre: nombre,
           descripcion: descripcion,
           tipo: tipo,
           ubicacion: ubicacion
         }}
    end
  end

  def nueva!(nombre, tipo, ubicacion, descripcion \\ nil) do
    case nueva(nombre, tipo, ubicacion, descripcion) do
      {:ok, punto} -> punto
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
