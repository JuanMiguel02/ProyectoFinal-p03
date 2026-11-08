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

  def nuevo(nombre, codigo, tipo, ubicacion, descripcion \\ nil) do
    cond do
      is_nil(nombre) or is_nil(ubicacion) ->
        {:error, "Nombre y ubicación son obligatorios"}

      tipo not in @tipos_permitidos ->
        {:error, "El tipo de punto :#{tipo} no es válido"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_punto_atencion: codigo,
           nombre: nombre,
           descripcion: descripcion,
           tipo: tipo,
           ubicacion: ubicacion
         }}
    end
  end

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:tipo, &Atom.to_string/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_ids(attrs),
         {:ok, tipo} <- obtener_tipo(attrs[:tipo]),
         {:ok, entidad} <- construir(Map.put(attrs, :tipo, tipo)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de punto de atención inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El punto de atención debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_ids(attrs) do
    if Enum.all?([attrs[:id], attrs[:codigo_punto_atencion]], &(is_binary(&1) and &1 != "")),
      do: :ok,
      else: {:error, "ID y código del punto de atención son obligatorios"}
  end

  defp obtener_tipo(tipo) when tipo in @tipos_permitidos, do: {:ok, tipo}

  defp obtener_tipo(tipo) when is_binary(tipo) do
    case Enum.find(@tipos_permitidos, &(Atom.to_string(&1) == tipo)) do
      nil -> {:error, "Tipo de punto de atención inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_tipo(_), do: {:error, "Tipo de punto de atención inválido"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos del punto de atención: #{Exception.message(error)}"}
  end
end
