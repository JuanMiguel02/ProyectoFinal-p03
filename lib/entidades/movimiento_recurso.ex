defmodule Emergencia.MovimientoRecurso do
  alias Emergencia.GeneradorID

  @moduledoc """
  Registra la trazabilidad y auditoría de las transferencias, ingresos, egresos
  o asignaciones de inventario entre distintas ubicaciones o solicitudes.
  """

  @tipos_movimiento_permitidos [:ingreso, :egreso, :transferencia, :asignacion]

  @enforce_keys [:id, :cantidad, :fecha, :tipo_movimiento]
  defstruct [
    :id,
    :id_inventario_origen,
    :id_inventario_destino,
    :id_asignacion,
    :cantidad,
    :fecha,
    :tipo_movimiento
  ]

  @type tipo_movimiento :: :ingreso | :egreso | :transferencia | :asignacion
  @type t :: %__MODULE__{
          id: String.t(),
          id_inventario_origen: String.t() | nil,
          id_inventario_destino: String.t() | nil,
          id_asignacion: String.t() | nil,
          cantidad: pos_integer(),
          fecha: DateTime.t(),
          tipo_movimiento: tipo_movimiento()
        }

  @doc """
  Crea un nuevo registro de MovimientoRecurso validando consistencia del movimiento.
  """
  def nueva(cantidad, tipo_movimiento, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha, DateTime.utc_now())
    id_origen = Keyword.get(opciones, :id_inventario_origen)
    id_destino = Keyword.get(opciones, :id_inventario_destino)
    id_asig = Keyword.get(opciones, :id_asignacion)

    with :ok <- validar_enum(:tipo_movimiento, tipo_movimiento, @tipos_movimiento_permitidos),
         :ok <- validar_cantidad(cantidad),
         :ok <- validar_consistencia_movimiento(tipo_movimiento, id_origen, id_destino) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         id_inventario_origen: id_origen,
         id_inventario_destino: id_destino,
         id_asignacion: id_asig,
         cantidad: cantidad,
         fecha: fecha,
         tipo_movimiento: tipo_movimiento
       }}
    end
  end

  @doc """
  Crea un nuevo MovimientoRecurso o lanza ArgumentError en caso de falla.
  """
  def nueva!(cantidad, tipo_movimiento, opciones \\ []) do
    case nueva(cantidad, tipo_movimiento, opciones) do
      {:ok, movimiento} -> movimiento
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_enum(campo, valor, permitidos) do
    if valor in permitidos do
      :ok
    else
      {:error,
       "El campo #{campo} con valor :#{valor} es inválido. Opciones: #{inspect(permitidos)}"}
    end
  end

  defp validar_cantidad(cantidad) do
    if is_integer(cantidad) and cantidad > 0 do
      :ok
    else
      {:error, "La cantidad del movimiento debe ser un número entero mayor a cero"}
    end
  end

  defp validar_consistencia_movimiento(:transferencia, origen, destino)
       when is_nil(origen) or is_nil(destino) do
    {:error, "Una transferencia requiere un inventario de origen y un inventario de destino"}
  end

  defp validar_consistencia_movimiento(:ingreso, _origen, destino) when is_nil(destino) do
    {:error, "Un ingreso requiere especificar un inventario de destino"}
  end

  defp validar_consistencia_movimiento(:egreso, origen, _destino) when is_nil(origen) do
    {:error, "Un egreso requiere especificar un inventario de origen"}
  end

  defp validar_consistencia_movimiento(_tipo, _origen, _destino), do: :ok
end
