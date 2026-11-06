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

  @doc """
  Crea un registro de InventarioUbicacion o lanza ArgumentError en caso de falla.
  """
  def nueva!(id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
    case nueva(id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
      {:ok, inventario} -> inventario
      {:error, motivo} -> raise ArgumentError, motivo
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
end
