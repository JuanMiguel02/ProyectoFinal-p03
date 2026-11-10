defmodule Emergencia.Necesidad do
  alias Emergencia.GeneradorID

  @tipos_permitidos [
    :alimento,
    :medicina,
    :agua,
    :refugio,
    :personal,
    :transporte,
    :otro,
    :primeros_auxilios,
    :rescate
  ]
  @prioridades_permitidas [:baja, :media, :alta, :critica]
  @estados_permitidos [:pendiente, :asignada, :en_atencion, :atendida, :cancelada]

  @enforce_keys [
    :id,
    :codigo_necesidad,
    :tipo,
    :cantidad_requerida,
    :cantidad_pendiente,
    :id_zona,
    :prioridad,
    :id_responsable,
    :estado,
    :entidad_asociada,
    :id_destinatario
  ]
  defstruct [
    :id,
    :codigo_necesidad,
    :tipo,
    :descripcion,
    :cantidad_requerida,
    :cantidad_pendiente,
    :id_zona,
    :prioridad,
    :id_responsable,
    :estado,
    :entidad_asociada,
    :id_destinatario
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
          id_responsable: String.t(),
          estado: estado_necesidad(),
          entidad_asociada: String.t(),
          id_destinatario: String.t()
        }

  @doc """
  Crea una nueva Necesidad validando mediante el pipeline 'with'.
  """
  def nueva(codigo, tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    estado = Keyword.get(opciones, :estado, :pendiente)

    with :ok <- validar_obligatorios(tipo, id_zona, prioridad),
         :ok <- validar_enum(:tipo, tipo, @tipos_permitidos),
         :ok <- validar_enum(:prioridad, prioridad, @prioridades_permitidas),
         :ok <- validar_enum(:estado, estado, @estados_permitidos),
         :ok <- validar_cantidad(cantidad),
         :ok <-
           validar_asociacion(
             Keyword.get(opciones, :id_responsable),
             Keyword.get(opciones, :id_destinatario),
             Keyword.get(opciones, :entidad_asociada)
           ) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         codigo_necesidad: codigo,
         tipo: tipo,
         descripcion: Keyword.get(opciones, :descripcion),
         cantidad_requerida: cantidad,
         cantidad_pendiente: cantidad,
         id_zona: id_zona,
         prioridad: prioridad,
         id_responsable: Keyword.get(opciones, :id_responsable),
         estado: estado,
         entidad_asociada: Keyword.get(opciones, :entidad_asociada),
         id_destinatario: Keyword.get(opciones, :id_destinatario)
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

  defp validar_asociacion(responsable, destinatario, entidad) do
    if texto_presente?(responsable) and texto_presente?(destinatario) and
         entidad in [
           "persona",
           "familia",
           "albergue",
           "punto_atencion",
           "centro_acopio",
           "zona"
         ] do
      :ok
    else
      {:error, "La necesidad requiere responsable y destinatario válidos"}
    end
  end

  defp texto_presente?(valor), do: is_binary(valor) and String.trim(valor) != ""

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:tipo, &Atom.to_string/1)
    |> Map.update!(:prioridad, &Atom.to_string/1)
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    mapa = completar_datos_legacy(mapa)
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, tipo} <- obtener_enum(attrs[:tipo], @tipos_permitidos, "tipo"),
         {:ok, prioridad} <- obtener_enum(attrs[:prioridad], @prioridades_permitidas, "prioridad"),
         {:ok, estado} <- obtener_enum(attrs[:estado], @estados_permitidos, "estado"),
         :ok <-
           validar_asociacion(
             attrs[:id_responsable],
             attrs[:id_destinatario],
             attrs[:entidad_asociada]
           ),
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

  defp completar_datos_legacy(mapa) do
    mapa
    |> Map.delete("tipo_destinatario")
    |> Map.delete(:tipo_destinatario)
    |> Map.update("id_responsable", "SISTEMA", &(&1 || "SISTEMA"))
    |> Map.update("id_destinatario", valor_mapa(mapa, "id_zona", :id_zona), fn valor ->
      valor || valor_mapa(mapa, "id_zona", :id_zona)
    end)
    |> Map.update("entidad_asociada", "zona", &(&1 || "zona"))
  end

  defp valor_mapa(mapa, clave_texto, clave_atomo),
    do: Map.get(mapa, clave_texto, Map.get(mapa, clave_atomo))

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

  @doc "Cancela una necesidad"
  def cancelar(%__MODULE__{estado: estado} = necesidad) when estado in [:pendiente, :asignada] do
    {:ok, %{necesidad | estado: :cancelada}}
  end

  def cancelar(_), do: {:error, "Solo se pueden cancelar necesidades pendientes o asignadas"}

  @doc "Cierra una necesidad marcándola como atendida"
  def cerrar(%__MODULE__{estado: estado} = necesidad) when estado in [:asignada, :en_atencion] do
    {:ok, %{necesidad | estado: :atendida}}
  end

  def cerrar(_), do: {:error, "Solo se pueden cerrar necesidades en proceso de atención"}
end
