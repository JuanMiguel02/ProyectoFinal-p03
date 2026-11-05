defmodule Emergencia.CentroAcopio do
  @moduledoc """
  Representa un centro de acopio asignado a una zona para la recepción,
  almacenamiento y distribución de recursos e insumos de emergencia.
  """

  @enforce_keys [:id, :nombre, :direccion, :capacidad, :id_zona]
  defstruct [:id, :nombre, :direccion, :capacidad, :id_zona]

  @type t :: %__MODULE__{
          id: String.t(),
          nombre: String.t(),
          direccion: String.t(),
          capacidad: pos_integer(),
          id_zona: String.t()
        }

  @doc """
  Crea un nuevo Centro de Acopio validando sus datos obligatorios y capacidad.
  """
  def nueva(id, nombre, direccion, capacidad, id_zona) do
    with :ok <- validar_obligatorios(id, nombre, direccion, id_zona),
         :ok <- validar_capacidad(capacidad) do
      {:ok,
       %__MODULE__{
         id: id,
         nombre: nombre,
         direccion: direccion,
         capacidad: capacidad,
         id_zona: id_zona
       }}
    end
  end

  @doc """
  Crea un nuevo Centro de Acopio o lanza ArgumentError en caso de falla.
  """
  def nueva!(id, nombre, direccion, capacidad, id_zona) do
    case nueva(id, nombre, direccion, capacidad, id_zona) do
      {:ok, centro} -> centro
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(id, nombre, direccion, id_zona) do
    if is_nil(id) or is_nil(nombre) or is_nil(direccion) or is_nil(id_zona) do
      {:error, "ID, nombre, dirección e ID de zona son obligatorios"}
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
end
