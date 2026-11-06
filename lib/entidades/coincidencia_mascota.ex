defmodule Emergencia.CoincidenciaMascota do
  alias Emergencia.GeneradorID

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
  def nueva(id_reporte_perdida, id_reporte_encontrada, opciones \\ []) do
    estado = Keyword.get(opciones, :estado, :pendiente)
    fecha = Keyword.get(opciones, :fecha_coincidencia, DateTime.utc_now())

    with :ok <- validar_obligatorios(id_reporte_perdida, id_reporte_encontrada),
         :ok <- validar_reportes_distintos(id_reporte_perdida, id_reporte_encontrada),
         :ok <- validar_enum(:estado, estado, @estados_permitidos) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         id_reporte_perdida: id_reporte_perdida,
         id_reporte_encontrada: id_reporte_encontrada,
         fecha_coincidencia: fecha,
         estado: estado
       }}
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(id_reporte_perdida, id_reporte_encontrada) do
    if is_nil(id_reporte_perdida) or is_nil(id_reporte_encontrada) do
      {:error, "ID de reporte de pérdida e ID de reporte de encontrada son obligatorios"}
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
      {:error,
       "El campo #{campo} con valor :#{valor} es inválido. Opciones: #{inspect(permitidos)}"}
    end
  end

  def a_map(%__MODULE__{} = entidad) do
    entidad
    |> Map.from_struct()
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.update!(:fecha_coincidencia, &DateTime.to_iso8601/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_id(attrs),
         {:ok, estado} <- obtener_estado(attrs[:estado]),
         {:ok, fecha} <- obtener_fecha(attrs[:fecha_coincidencia]),
         {:ok, entidad} <-
           construir(attrs |> Map.put(:estado, estado) |> Map.put(:fecha_coincidencia, fecha)) do
      {:ok, entidad}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de coincidencia inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La coincidencia debe ser un mapa válido"}

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
        else: {:error, "ID de coincidencia inválido"}
      )

  defp obtener_estado(estado) when estado in @estados_permitidos, do: {:ok, estado}

  defp obtener_estado(estado) when is_binary(estado) do
    case Enum.find(@estados_permitidos, &(Atom.to_string(&1) == estado)) do
      nil -> {:error, "Estado de coincidencia inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_estado(_), do: {:error, "Estado de coincidencia inválido"}
  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha de coincidencia inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha de coincidencia inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de coincidencia: #{Exception.message(error)}"}
  end
end
