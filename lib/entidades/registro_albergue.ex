defmodule Emergencia.RegistroAlbergue do
  alias Emergencia.GeneradorID

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
  def nuevo(id_albergue, id_persona, tipo_movimiento, opciones \\ []) do
    fecha = Keyword.get(opciones, :fecha, DateTime.utc_now())

    with :ok <- validar_obligatorios(id_albergue, id_persona),
         :ok <- validar_enum(:tipo_movimiento, tipo_movimiento, @tipos_movimiento_permitidos) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         id_albergue: id_albergue,
         id_persona: id_persona,
         tipo_movimiento: tipo_movimiento,
         fecha: fecha
       }}
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(id_albergue, id_persona) do
    if is_nil(id_albergue) or is_nil(id_persona) do
      {:error, "ID de albergue e ID de persona son obligatorios"}
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
    |> Map.update!(:tipo_movimiento, &Atom.to_string/1)
    |> Map.update!(:fecha, &DateTime.to_iso8601/1)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
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
      {:error, "Mapa de registro de albergue inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El registro de albergue debe ser un mapa válido"}

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
        else: {:error, "ID de registro inválido"}
      )

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
      _ -> {:error, "Fecha del registro inválida"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha del registro inválida"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos del registro: #{Exception.message(error)}"}
  end
end
