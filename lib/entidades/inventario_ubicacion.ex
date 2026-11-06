defmodule Emergencia.InventarioUbicacion do
  alias Emergencia.GeneradorID

  @moduledoc """
  Gestiona la existencia y disponibilidad física de un recurso determinado
  dentro de una ubicación específica (albergue, centro de acopio o punto de atención).
  """

  @tipos_ubicacion_permitidos [:albergue, :centro_acopio, :punto_atencion]

  @enforce_keys [:id, :id_ubicacion, :tipo_ubicacion, :id_recurso, :cantidad_disponible]
  defstruct [:id, :id_ubicacion, :tipo_ubicacion, :id_recurso, :cantidad_disponible]

  @type tipo_ubicacion :: :albergue | :centro_acopio | :punto_atencion
  @type t :: %__MODULE__{
          id: String.t(),
          id_ubicacion: String.t(),
          tipo_ubicacion: tipo_ubicacion(),
          id_recurso: String.t(),
          cantidad_disponible: non_neg_integer()
        }

  @doc """
  Crea un nuevo registro de Inventario en una Ubicación determinada.
  """
  def nueva(id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
    with :ok <- validar_obligatorios(id_ubicacion, id_recurso),
         :ok <- validar_enum(:tipo_ubicacion, tipo_ubicacion, @tipos_ubicacion_permitidos),
         :ok <- validar_cantidad(cantidad) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         id_ubicacion: id_ubicacion,
         tipo_ubicacion: tipo_ubicacion,
         id_recurso: id_recurso,
         cantidad_disponible: cantidad
       }}
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(id_ubicacion, id_recurso) do
    if is_nil(id_ubicacion) or is_nil(id_recurso) do
      {:error, "ID de ubicación e ID de recurso son obligatorios"}
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

  defp validar_cantidad(cantidad) do
    if is_integer(cantidad) and cantidad >= 0 do
      :ok
    else
      {:error, "La cantidad disponible debe ser un número entero no negativo"}
    end
  end

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:tipo_ubicacion, &Atom.to_string/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, tipo} <- obtener_tipo(attrs[:tipo_ubicacion]),
         {:ok, entidad} <- construir(Map.put(attrs, :tipo_ubicacion, tipo)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de inventario inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El inventario debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_id(attrs),
    do:
      if(is_binary(attrs[:id]) and attrs[:id] != "",
        do: :ok,
        else: {:error, "ID de inventario inválido"}
      )

  defp obtener_tipo(tipo) when tipo in @tipos_ubicacion_permitidos, do: {:ok, tipo}

  defp obtener_tipo(tipo) when is_binary(tipo) do
    case Enum.find(@tipos_ubicacion_permitidos, &(Atom.to_string(&1) == tipo)) do
      nil -> {:error, "Tipo de ubicación inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_tipo(_), do: {:error, "Tipo de ubicación inválido"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de inventario: #{Exception.message(error)}"}
  end
end
