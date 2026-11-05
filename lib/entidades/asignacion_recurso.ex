defmodule Emergencia.AsignacionRecurso do
  @estados_permitidos [:asignado, :entregado, :cancelado]

  @enforce_keys [:id, :id_necesidad, :id_inventario, :cantidad_asignada, :fecha_asignada, :estado]
  defstruct [:id, :id_necesidad, :id_inventario, :cantidad_asignada, :fecha_asignada, :estado]

  @type estado_asignacion :: :asignado | :entregado | :cancelado
  @type t :: %__MODULE__{
          id: String.t(),
          id_necesidad: String.t(),
          id_inventario: String.t(),
          cantidad_asignada: pos_integer(),
          fecha_asignada: DateTime.t(),
          estado: estado_asignacion()
        }

  @doc """
  Crea una nueva asignación de recurso. Asigna la fecha actual y estado :asignado por defecto.
  """
  def nueva(id, id_necesidad, id_inventario, cantidad, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha_asignada, DateTime.utc_now())
    estado = Keyword.get(opciones, :estado, :asignado)

    cond do
      is_nil(id) or is_nil(id_necesidad) or is_nil(id_inventario) ->
        {:error, "ID de asignación, ID de necesidad e ID de inventario son obligatorios"}
      not is_integer(cantidad) or cantidad <= 0 ->
        {:error, "La cantidad asignada debe ser un número entero mayor a cero"}
      estado not in @estados_permitidos ->
        {:error, "Estado :#{estado} inválido. Opciones: #{inspect(@estados_permitidos)}"}
      true ->
        {:ok, %__MODULE__{
          id: id,
          id_necesidad: id_necesidad,
          id_inventario: id_inventario,
          cantidad_asignada: cantidad,
          fecha_asignada: fecha,
          estado: estado
        }}
    end
  end

  def nueva!(id, id_necesidad, id_inventario, cantidad, opciones \\ []) do
    case nueva(id, id_necesidad, id_inventario, cantidad, opciones) do
      {:ok, asignacion} -> asignacion
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
