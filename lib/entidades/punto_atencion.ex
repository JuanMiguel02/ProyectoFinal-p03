defmodule Emergencia.PuntoAtencion do
  @tipos_permitidos [:medico, :logistico, :distribucion]

  @enforce_keys [:id, :nombre, :tipo, :ubicacion]
  defstruct [:id, :nombre, :descripcion, :tipo, :ubicacion]

  @type tipo_punto :: :medico | :logistico | :distribucion
  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          descripcion: String.t() | nil,
          tipo: tipo_punto(),
          ubicacion: String.t()
        }

  def nueva(id, nombre, tipo, ubicacion, descripcion \\ nil) do
    cond do
      is_nil(id) or is_nil(nombre) or is_nil(ubicacion) ->
        {:error, "ID, nombre y ubicación son obligatorios"}
      tipo not in @tipos_permitidos ->
        {:error, "El tipo de punto :#{tipo} no es válido"}
      true ->
        {:ok, %__MODULE__{
          id: id,
          nombre: nombre,
          descripcion: descripcion,
          tipo: tipo,
          ubicacion: ubicacion
        }}
    end
  end

  def nueva!(id, nombre, tipo, ubicacion, descripcion \\ nil) do
    case nueva(id, nombre, tipo, ubicacion, descripcion) do
      {:ok, punto} -> punto
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
