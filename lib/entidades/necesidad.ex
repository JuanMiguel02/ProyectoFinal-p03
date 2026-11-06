defmodule Emergencia.Necesidad do
  alias Emergencia.GeneradorID

  @tipos_permitidos [:alimento, :medicina, :agua, :refugio, :personal, :transporte, :otro]
  @prioridades_permitidas [:baja, :media, :alta, :critica]
  @estados_permitidos [:pendiente, :en_proceso, :cubierta, :cancelada]

  @enforce_keys [
    :id,
    :codigo_necesidad,
    :tipo,
    :cantidad_requerida,
    :id_zona,
    :prioridad,
    :estado
  ]
  defstruct [
    :id,
    :codigo_necesidad,
    :tipo,
    :descripcion,
    :cantidad_requerida,
    :id_zona,
    :prioridad,
    :id_responsable,
    :estado,
    :entidad_asociada,
    :id_destinatario,
    :tipo_destinatario
  ]

  @type tipo_necesidad ::
          :alimento | :medicina | :agua | :refugio | :personal | :transporte | :otro
  @type prioridad :: :baja | :media | :alta | :critica
  @type estado_necesidad :: :pendiente | :en_proceso | :cubierta | :cancelada
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_necesidad: String.t(),
          tipo: tipo_necesidad(),
          descripcion: String.t() | nil,
          cantidad_requerida: pos_integer(),
          id_zona: String.t(),
          prioridad: prioridad(),
          id_responsable: String.t() | nil,
          estado: estado_necesidad(),
          entidad_asociada: String.t() | nil,
          id_destinatario: String.t() | nil,
          tipo_destinatario: String.t() | nil
        }

  @doc """
  Crea una nueva Necesidad validando mediante el pipeline 'with'.
  """
  def nueva(tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    estado = Keyword.get(opciones, :estado, :pendiente)

    with :ok <- validar_obligatorios(tipo, id_zona, prioridad),
         :ok <- validar_enum(:tipo, tipo, @tipos_permitidos),
         :ok <- validar_enum(:prioridad, prioridad, @prioridades_permitidas),
         :ok <- validar_enum(:estado, estado, @estados_permitidos),
         :ok <- validar_cantidad(cantidad) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         codigo_necesidad: GeneradorID.generar("NEC"),
         tipo: tipo,
         descripcion: Keyword.get(opciones, :descripcion),
         cantidad_requerida: cantidad,
         id_zona: id_zona,
         prioridad: prioridad,
         id_responsable: Keyword.get(opciones, :id_responsable),
         estado: estado,
         entidad_asociada: Keyword.get(opciones, :entidad_asociada),
         id_destinatario: Keyword.get(opciones, :id_destinatario),
         tipo_destinatario: Keyword.get(opciones, :tipo_destinatario)
       }}
    end
  end

  @doc """
  Crea una nueva Necesidad o lanza ArgumentError si falla la validación.
  """
  def nueva!(tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    case nueva(tipo, cantidad, id_zona, prioridad, opciones) do
      {:ok, necesidad} -> necesidad
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(tipo, id_zona, prioridad) do
    if is_nil(tipo) or is_nil(id_zona) or is_nil(prioridad) do
      {:error, "Tipo, ID de zona y prioridad son obligatorios"}
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
    if is_integer(cantidad) and cantidad > 0 do
      :ok
    else
      {:error, "La cantidad requerida debe ser un número entero mayor a cero"}
    end
  end
end
