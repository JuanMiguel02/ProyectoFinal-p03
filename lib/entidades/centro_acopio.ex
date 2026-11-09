defmodule Emergencia.CentroAcopio do
  alias Emergencia.GeneradorID

  @moduledoc """
  Representa un centro de acopio asignado a una zona para la recepción,
  almacenamiento y distribución de recursos e insumos de emergencia.
  """

  @enforce_keys [:id, :codigo_centro_acopio, :nombre, :direccion, :capacidad, :id_zona]
  defstruct [:id, :codigo_centro_acopio, :nombre, :direccion, :capacidad, :id_zona]

  @type t :: %__MODULE__{
          id: String.t(),
          codigo_centro_acopio: String.t(),
          nombre: String.t(),
          direccion: String.t(),
          capacidad: pos_integer(),
          id_zona: String.t()
        }

  @doc """
  Crea un nuevo Centro de Acopio validando sus datos obligatorios y capacidad.
  """
  def nuevo(nombre, codigo, direccion, capacidad, id_zona) do

    with :ok <- validar_obligatorios(nombre, direccion, id_zona),
         :ok <- validar_capacidad(capacidad) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         codigo_centro_acopio: codigo,
         nombre: nombre,
         direccion: direccion,
         capacidad: capacidad,
         id_zona: id_zona
       }}
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(nombre, direccion, id_zona) do
    if is_nil(nombre) or is_nil(direccion) or is_nil(id_zona) do
      {:error, "Nombre, dirección e ID de zona son obligatorios"}
    else
      :ok
    end
  end

  defp validar_capacidad(capacidad) do
    if is_integer(capacidad) and capacidad > 0 do
      :ok
    else
      {:error, "La capacidad debe ser un número entero mayor a cero"}
    end
  end

  def a_map(%__MODULE__{} = entidad),
    do: entidad |> Map.from_struct() |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar_campos(mapa, campos),
         :ok <- validar_ids(attrs),
         {:ok, entidad} <- construir(attrs) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de centro de acopio inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El centro de acopio debe ser un mapa válido"}

  defp normalizar_campos(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {clave, valor}, {:ok, acc} ->
      campo =
        if is_atom(clave),
          do: clave,
          else: Enum.find(campos, &(Atom.to_string(&1) == clave))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, valor)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(clave)}"}}
    end)
  end

  defp validar_ids(attrs) do
    if Enum.all?([attrs[:id], attrs[:codigo_centro_acopio]], &(is_binary(&1) and &1 != "")),
      do: :ok,
      else: {:error, "ID y código del centro de acopio son obligatorios"}
  end

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos del centro: #{Exception.message(error)}"}
  end
end
