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

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:tipo, &Atom.to_string/1)
    |> Map.update!(:prioridad, &Atom.to_string/1)
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, tipo} <- obtener_enum(attrs[:tipo], @tipos_permitidos, "tipo"),
         {:ok, prioridad} <- obtener_enum(attrs[:prioridad], @prioridades_permitidas, "prioridad"),
         {:ok, estado} <- obtener_enum(attrs[:estado], @estados_permitidos, "estado"),
         {:ok, entidad} <-
           construir(
             attrs
             |> Map.put(:tipo, tipo)
             |> Map.put(:prioridad, prioridad)
             |> Map.put(:estado, estado)
           ) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de necesidad inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La necesidad debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_id(attrs) do
    if is_binary(attrs[:id]) and attrs[:id] != "" and
         is_binary(attrs[:codigo_necesidad]) and attrs[:codigo_necesidad] != "",
       do: :ok,
       else: {:error, "ID y código de necesidad son obligatorios"}
  end

  defp obtener_enum(valor, permitidos, campo) when is_binary(valor) do
    case Enum.find(permitidos, &(Atom.to_string(&1) == valor)) do
      nil -> {:error, "Valor inválido para #{campo}"}
      atom -> {:ok, atom}
    end
  end

  defp obtener_enum(valor, permitidos, _campo)
       when valor in [
              :alimento,
              :medicina,
              :agua,
              :refugio,
              :personal,
              :transporte,
              :otro,
              :baja,
              :media,
              :alta,
              :critica,
              :pendiente,
              :en_proceso,
              :cubierta,
              :cancelada
            ] do
    if valor in permitidos, do: {:ok, valor}, else: {:error, "Enum inválido"}
  end

  defp obtener_enum(_valor, _permitidos, campo), do: {:error, "Valor inválido para #{campo}"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de necesidad: #{Exception.message(error)}"}
  end
end
