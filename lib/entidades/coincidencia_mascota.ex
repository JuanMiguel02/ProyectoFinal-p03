defmodule Emergencia.CoincidenciaMascota do
  @moduledoc """
  Representa la vinculación o emparejamiento entre un reporte de mascota perdida
  y uno de mascota encontrada, gestionando el ciclo de confirmación del hallazgo.
  """

  @estados_permitidos [:pendiente, :confirmada, :rechazada]

  @enforce_keys [:id, :id_reporte_perdida, :id_reporte_encontrada, :estado, :fecha_coincidencia]
  defstruct [:id, :id_reporte_perdida, :id_reporte_encontrada, :fecha_coincidencia, :estado]

  @type estado_coincidencia :: :pendiente | :confirmada | :rechazada
  @type t :: %__MODULE__{
          id: String.t(),
          id_reporte_perdida: String.t(),
          id_reporte_encontrada: String.t(),
          fecha_coincidencia: DateTime.t(),
          estado: estado_coincidencia()
        }

  @doc """
  Crea una nueva CoincidenciaMascota vinculando un reporte de pérdida y uno de hallazgo.
  """
  def nueva(id, id_reporte_perdida, id_reporte_encontrada, opciones \\ []) do
    estado = Keyword.get(opciones, :estado, :pendiente)
    fecha = Keyword.get(opciones, :fecha_coincidencia, DateTime.utc_now())

    with :ok <- validar_obligatorios(id, id_reporte_perdida, id_reporte_encontrada),
         :ok <- validar_reportes_distintos(id_reporte_perdida, id_reporte_encontrada),
         :ok <- validar_enum(:estado, estado, @estados_permitidos) do
      {:ok,
       %__MODULE__{
         id: id,
         id_reporte_perdida: id_reporte_perdida,
         id_reporte_encontrada: id_reporte_encontrada,
         fecha_coincidencia: fecha,
         estado: estado
       }}
    end
  end

  @doc """
  Crea una nueva CoincidenciaMascota o lanza ArgumentError en caso de falla.
  """
  def nueva!(id, id_reporte_perdida, id_reporte_encontrada, opciones \\ []) do
    case nueva(id, id_reporte_perdida, id_reporte_encontrada, opciones) do
      {:ok, coincidencia} -> coincidencia
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(id, id_reporte_perdida, id_reporte_encontrada) do
    if is_nil(id) or is_nil(id_reporte_perdida) or is_nil(id_reporte_encontrada) do
      {:error, "ID de coincidencia, ID de reporte de pérdida e ID de reporte de encontrada son obligatorios"}
    else
      :ok
    end
  end

  defp validar_reportes_distintos(id_perdida, id_encontrada) do
    if id_perdida == id_encontrada do
      {:error, "Un reporte de mascota no puede coincidir consigo mismo"}
    else
      :ok
    end
  end

  defp validar_enum(campo, valor, permitidos) do
    if valor in permitidos do
      :ok
    else
      {:error, "El campo #{campo} con valor :#{valor} es inválido. Opciones: #{inspect(permitidos)}"}
    end
  end
end
