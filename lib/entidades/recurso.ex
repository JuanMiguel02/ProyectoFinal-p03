defmodule Emergencia.Recurso do
  @moduledoc """
  Define el catálogo maestro de recursos (ej. agua, medicamentos, cobijas)
  especificando su categoría, unidad de medida y conservando su historial de cambios.
  """

  alias Emergencia.GeneradorID

  @categorias_permitidas [:alimento, :agua, :medicina, :herramienta, :vestimenta, :equipo, :otro]

  @enforce_keys [:id, :codigo, :nombre, :categoria, :unidad_medida]
  defstruct [:id, :codigo, :nombre, :categoria, :unidad_medida]

  @type categoria_recurso ::
          :alimento | :agua | :medicina | :herramienta | :vestimenta | :equipo | :otro
  @type t :: %__MODULE__{
          id: String.t(),
          codigo: String.t(),
          nombre: String.t(),
          categoria: categoria_recurso(),
          unidad_medida: String.t()
        }

  @doc """
  Crea una nueva definición de Recurso validando sus atributos requeridos.
  """
  def nuevo(codigo, nombre, categoria, unidad_medida, _opciones \\ []) do
    with :ok <- validar_obligatorios(codigo, nombre, unidad_medida),
         :ok <- validar_enum(:categoria, categoria, @categorias_permitidas) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         codigo: codigo,
         nombre: nombre,
         categoria: categoria,
         unidad_medida: unidad_medida
       }}
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(codigo, nombre, unidad_medida) do
    if is_nil(codigo) or is_nil(nombre) or is_nil(unidad_medida) do
      {:error, "Código, nombre y unidad de medida son obligatorios"}
    else
      :ok
    end
  end

  defp validar_enum(campo, valor, permitidos) do
    if valor in permitidos do
      :ok
    else
      {:error,
       "El campo #{campo} con valor :#{valor} es inválido. Opciones: #{inspect(permitidos)}"}
    end
  end

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:categoria, &Atom.to_string/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    mapa =
      mapa
      |> Map.put_new("codigo", Map.get(mapa, "codigo_recurso"))
      |> Map.delete("codigo_recurso")
      |> Map.delete("historial")

    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_ids(attrs),
         {:ok, categoria} <- obtener_categoria(attrs[:categoria]),
         {:ok, entidad} <- construir(Map.put(attrs, :categoria, categoria)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de recurso inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El recurso debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_ids(attrs) do
    if Enum.all?([attrs[:id], attrs[:codigo]], &(is_binary(&1) and &1 != "")),
      do: :ok,
      else: {:error, "ID y código de recurso son obligatorios"}
  end

  defp obtener_categoria(categoria) when categoria in @categorias_permitidas, do: {:ok, categoria}

  defp obtener_categoria(categoria) when is_binary(categoria) do
    case Enum.find(@categorias_permitidas, &(Atom.to_string(&1) == categoria)) do
      nil -> {:error, "Categoría de recurso inválida"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_categoria(_), do: {:error, "Categoría de recurso inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de recurso: #{Exception.message(error)}"}
  end
end
