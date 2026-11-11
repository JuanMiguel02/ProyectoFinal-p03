defmodule Emergencia.MovimientoRecurso do
  alias Emergencia.GeneradorID
  alias Emergencia.Reloj

  @moduledoc """
  Registra la trazabilidad de ingresos, transferencias y asignaciones de recursos.
  """

  @tipos_movimiento_permitidos [:ingreso, :transferencia, :asignacion]

  @enforce_keys [:id, :cantidad, :fecha, :tipo_movimiento]
  defstruct [
    :id,
    :id_recurso,
    :ubicacion_origen,
    :ubicacion_destino,
    :cantidad,
    :fecha,
    :tipo_movimiento
  ]

  @type tipo_movimiento :: :ingreso | :transferencia | :asignacion
  @type t :: %__MODULE__{
          id: String.t(),
          id_recurso: String.t() | nil,
          ubicacion_origen: String.t() | nil,
          ubicacion_destino: String.t() | nil,
          cantidad: pos_integer(),
          fecha: DateTime.t(),
          tipo_movimiento: tipo_movimiento()
        }

  def nuevo(cantidad, tipo_movimiento, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha, Reloj.ahora_local())
    ubicacion_origen = Keyword.get(opciones, :ubicacion_origen)
    ubicacion_destino = Keyword.get(opciones, :ubicacion_destino)

    with :ok <- validar_enum(:tipo_movimiento, tipo_movimiento, @tipos_movimiento_permitidos),
         :ok <- validar_cantidad(cantidad),
         :ok <-
           validar_consistencia_movimiento(
             tipo_movimiento,
             ubicacion_origen,
             ubicacion_destino
           ) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         id_recurso: Keyword.get(opciones, :id_recurso),
         ubicacion_origen: ubicacion_origen,
         ubicacion_destino: ubicacion_destino,
         cantidad: cantidad,
         fecha: fecha,
         tipo_movimiento: tipo_movimiento
       }}
    end
  end

  defp validar_enum(campo, valor, permitidos) do
    if valor in permitidos,
      do: :ok,
      else: {:error, "El campo #{campo} con valor :#{valor} es inválido"}
  end

  defp validar_cantidad(cantidad) when is_integer(cantidad) and cantidad > 0, do: :ok

  defp validar_cantidad(_),
    do: {:error, "La cantidad del movimiento debe ser un número entero mayor a cero"}

  defp validar_consistencia_movimiento(:transferencia, origen, destino)
       when is_nil(origen) or is_nil(destino),
       do: {:error, "Una transferencia requiere ubicación de origen y ubicación de destino"}

  defp validar_consistencia_movimiento(:ingreso, _origen, destino) when is_nil(destino),
    do: {:error, "Un ingreso requiere especificar una ubicación de destino"}

  defp validar_consistencia_movimiento(_tipo, _origen, _destino), do: :ok

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:tipo_movimiento, &Atom.to_string/1)
    |> Map.update!(:fecha, &DateTime.to_iso8601/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    mapa =
      mapa
      |> Map.put_new("ubicacion_origen", nil)
      |> Map.put_new("ubicacion_destino", nil)
      |> Map.put_new("id_recurso", nil)

    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, tipo} <- obtener_tipo(attrs[:tipo_movimiento]),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha]),
         {:ok, entidad} <-
           construir(attrs |> Map.put(:tipo_movimiento, tipo) |> Map.put(:fecha, fecha)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de movimiento inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El movimiento debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_id(attrs) do
    if is_binary(attrs[:id]) and attrs[:id] != "",
      do: :ok,
      else: {:error, "ID de movimiento inválido"}
  end

  defp obtener_tipo(tipo) when tipo in @tipos_movimiento_permitidos, do: {:ok, tipo}

  defp obtener_tipo(tipo) when is_binary(tipo) do
    case Enum.find(@tipos_movimiento_permitidos, &(Atom.to_string(&1) == tipo)) do
      nil -> {:error, "Tipo de movimiento inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_tipo(_), do: {:error, "Tipo de movimiento inválido"}
  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha de movimiento inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha de movimiento inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de movimiento: #{Exception.message(error)}"}
  end
end
