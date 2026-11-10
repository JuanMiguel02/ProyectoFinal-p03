defmodule Emergencia.ReporteMascota do
  alias Emergencia.GeneradorID

  @moduledoc """
  Registra los reportes de mascotas extraviadas o encontradas en una zona afectada,
  detallando sus características físicas, estado del reporte y usuario de contacto.
  """

  @tipos_permitidos [:perdida, :encontrada]
  @tamanos_permitidos [:pequeno, :mediano, :grande]
  @estados_permitidos [:activa, :posible_coincidencia, :resuelta]

  @enforce_keys [:id, :tipo, :especie, :color, :tamano, :estado, :id_zona, :id_usuario_contacto]
  defstruct [
    :id,
    :tipo,
    :especie,
    :nombre,
    :caracteristicas,
    :color,
    :tamano,
    :estado,
    :fecha_reporte,
    :id_zona,
    :id_usuario_contacto
  ]

  @type tipo_reporte :: :perdida | :encontrada
  @type tamano :: :pequeno | :mediano | :grande
  @type estado_reporte :: :activa | :posible_coincidencia | :resuelta
  @type t :: %__MODULE__{
          id: String.t(),
          tipo: tipo_reporte(),
          especie: String.t(),
          nombre: String.t() | nil,
          caracteristicas: String.t() | nil,
          color: String.t(),
          tamano: tamano(),
          estado: estado_reporte(),
          fecha_reporte: DateTime.t(),
          id_zona: String.t(),
          id_usuario_contacto: String.t()
        }

  @doc """
  Crea un nuevo ReporteMascota validando los tipos y campos obligatorios.
  """
  def nueva(tipo, especie, color, tamano, id_zona, id_contacto, opciones \\ []) do
    estado = Keyword.get(opciones, :estado, :activa)
    fecha = Keyword.get(opciones, :fecha_reporte, DateTime.utc_now())

    with :ok <- validar_obligatorios(especie, color, id_zona, id_contacto),
         :ok <- validar_enum(:tipo, tipo, @tipos_permitidos),
         :ok <- validar_enum(:tamano, tamano, @tamanos_permitidos),
         :ok <- validar_enum(:estado, estado, @estados_permitidos) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         tipo: tipo,
         especie: String.downcase(String.trim(especie)),
         nombre: Keyword.get(opciones, :nombre),
         caracteristicas: Keyword.get(opciones, :caracteristicas),
         color: color,
         tamano: tamano,
         estado: estado,
         fecha_reporte: fecha,
         id_zona: id_zona,
         id_usuario_contacto: id_contacto
       }}
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(especie, color, id_zona, id_contacto) do
    if is_nil(especie) or is_nil(color) or is_nil(id_zona) or is_nil(id_contacto) do
      {:error, "Especie, color, ID de zona e ID de usuario de contacto son obligatorios"}
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

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:tipo, &Atom.to_string/1)
    |> Map.update!(:tamano, &Atom.to_string/1)
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.update!(:fecha_reporte, &DateTime.to_iso8601/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, tipo} <- obtener_enum(attrs[:tipo], @tipos_permitidos, :tipo),
         {:ok, tamano} <- obtener_enum(attrs[:tamano], @tamanos_permitidos, :tamano),
         {:ok, estado} <- obtener_enum(attrs[:estado], @estados_permitidos, :estado),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha_reporte]),
         {:ok, entidad} <-
           construir(
             attrs
             |> Map.put(:tipo, tipo)
             |> Map.put(:tamano, tamano)
             |> Map.put(:estado, estado)
             |> Map.put(:fecha_reporte, fecha)
           ) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de reporte de mascota inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El reporte de mascota debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_id(attrs),
    do:
      if(is_binary(attrs[:id]) and attrs[:id] != "",
        do: :ok,
        else: {:error, "ID de reporte inválido"}
      )

  defp obtener_enum(valor, permitidos, _campo)
       when valor in @tipos_permitidos or valor in @tamanos_permitidos or
              valor in @estados_permitidos do
    if valor in permitidos, do: {:ok, valor}, else: {:error, "Valor de reporte inválido"}
  end

  defp obtener_enum(valor, permitidos, campo) when is_binary(valor) do
    case Enum.find(permitidos, &(Atom.to_string(&1) == valor)) do
      nil -> {:error, "Campo #{campo} inválido"}
      atom -> {:ok, atom}
    end
  end

  defp obtener_enum(_, _, campo), do: {:error, "Campo #{campo} inválido"}
  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha de reporte inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha de reporte inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de reporte: #{Exception.message(error)}"}
  end

  @doc "Valida y aplica transiciones estrictas de estado para el reporte"
  def cambiar_estado(%__MODULE__{} = reporte, nuevo_estado) do
    transiciones_validas = %{
      activa: [:posible_coincidencia, :resuelta],
      posible_coincidencia: [:activa, :resuelta],
      resuelta: [] # Es un estado final, no se puede reabrir
    }

    if nuevo_estado in @estados_permitidos do
      if nuevo_estado in Map.get(transiciones_validas, reporte.estado, []) do
        {:ok, %{reporte | estado: nuevo_estado}}
      else
        {:error, "Transición no permitida: No se puede pasar de '#{reporte.estado}' a '#{nuevo_estado}'"}
      end
    else
      {:error, "Estado de reporte inválido"}
    end
  end
end
