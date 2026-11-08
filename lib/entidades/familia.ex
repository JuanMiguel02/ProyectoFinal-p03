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
  def nueva(nombre, codigo) do
    cond do
      is_nil(nombre) ->
        {:error, "El nombre es obligatorio"}

      String.trim(nombre) == "" ->
        {:error, "El nombre de la familia no puede estar vacío"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_familia: codigo,
           nombre: nombre
         }}
    end
  end

  def a_map(%__MODULE__{} = familia),
    do: familia |> Map.from_struct() |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar_campos(mapa, campos),
         :ok <- validar_ids(attrs),
         {:ok, familia} <- construir(attrs) do
      {:ok, familia}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de familia inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La familia debe ser un mapa válido"}

  defp normalizar_campos(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {clave, valor}, {:ok, acc} ->
      campo =
        if is_atom(clave), do: clave, else: Enum.find(campos, &(Atom.to_string(&1) == clave))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, valor)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(clave)}"}}
    end)
  end

  defp validar_ids(attrs) do
    if is_binary(attrs[:id]) and attrs[:id] != "" and
         is_binary(attrs[:codigo_familia]) and attrs[:codigo_familia] != "",
       do: :ok,
       else: {:error, "ID y código de familia son obligatorios"}
  end

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de familia: #{Exception.message(error)}"}
  end
end
