defmodule Emergencia.RegistroAlbergue do
  @moduledoc """
  Registra y audita las entradas y salidas de personas afectadas en un
  albergue específico, registrando la fecha exacta del movimiento.
  """

  @tipos_movimiento_permitidos [:ingreso, :salida]

  @enforce_keys [:id, :id_albergue, :id_persona, :tipo_movimiento, :fecha]
  defstruct [:id, :id_albergue, :id_persona, :tipo_movimiento, :fecha]

  @type tipo_movimiento :: :ingreso | :salida
  @type t :: %__MODULE__{
          id: String.t(),
          id_albergue: String.t(),
          id_persona: String.t(),
          tipo_movimiento: tipo_movimiento(),
          fecha: DateTime.t()
        }

  @doc """
  Crea un nuevo registro de entrada o salida de albergue.
  """
  def nueva(id, id_albergue, id_persona, tipo_movimiento, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha, DateTime.utc_now())

    with :ok <- validar_obligatorios(id, id_albergue, id_persona),
         :ok <- validar_enum(:tipo_movimiento, tipo_movimiento, @tipos_movimiento_permitidos) do
      {:ok,
       %__MODULE__{
         id: id,
         id_albergue: id_albergue,
         id_persona: id_persona,
         tipo_movimiento: tipo_movimiento,
         fecha: fecha
       }}
    end
  end

  @doc """
  Crea un nuevo RegistroAlbergue o lanza ArgumentError en caso de falla.
  """
  def nueva!(id, id_albergue, id_persona, tipo_movimiento, opciones \\ []) do
    case nueva(id, id_albergue, id_persona, tipo_movimiento, opciones) do
      {:ok, registro} -> registro
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(id, id_albergue, id_persona) do
    if is_nil(id) or is_nil(id_albergue) or is_nil(id_persona) do
      {:error, "ID de registro, ID de albergue e ID de persona son obligatorios"}
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
