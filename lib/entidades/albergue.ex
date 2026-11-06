defmodule Emergencia.Albergue do
  alias Emergencia.GeneradorID

  @moduledoc """
  Gestiona los albergues temporales de una zona, supervisando el límite
  de capacidad máxima y el control de ocupación en tiempo real.
  """

  @enforce_keys [:id, :codigo_albergue, :codigo, :nombre, :id_zona, :capacidad_maxima]
  defstruct [
    :id,
    :codigo_albergue,
    :codigo,
    :nombre,
    :id_zona,
    :capacidad_maxima,
    ocupacion_actual: 0
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          codigo_albergue: String.t(),
          codigo: String.t(),
          nombre: String.t(),
          id_zona: String.t(),
          capacidad_maxima: pos_integer(),
          ocupacion_actual: non_neg_integer()
        }

  @doc """
  Crea un nuevo Albergue validando la consistencia entre capacidad y ocupación.
  """
  def nuevo(codigo, nombre, id_zona, capacidad_maxima, opciones \\ []) do
    ocupacion = Keyword.get(opciones, :ocupacion_actual, 0)
    id_final = GeneradorID.generar_uuid()

    with :ok <- validar_obligatorios(codigo, nombre, id_zona),
         :ok <- validar_capacidades(capacidad_maxima, ocupacion) do
      {:ok,
       %__MODULE__{
         id: id_final,
         codigo_albergue: GeneradorID.generar("ALB"),
         codigo: codigo,
         nombre: nombre,
         id_zona: id_zona,
         capacidad_maxima: capacidad_maxima,
         ocupacion_actual: ocupacion
       }}
    end
  end

  @doc """
  Crea un nuevo Albergue o lanza ArgumentError en caso de falla.
  """
  def nuevo!(codigo, nombre, id_zona, capacidad_maxima, opciones \\ []) do
    case nuevo(codigo, nombre, id_zona, capacidad_maxima, opciones) do
      {:ok, albergue} -> albergue
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(codigo, nombre, id_zona) do
    if is_nil(codigo) or is_nil(nombre) or is_nil(id_zona) do
      {:error, "Código, nombre e ID de zona son obligatorios"}
    else
      :ok
    end
  end

  defp validar_capacidades(capacidad_maxima, ocupacion) do
    cond do
      not is_integer(capacidad_maxima) or capacidad_maxima <= 0 ->
        {:error, "La capacidad máxima debe ser un número entero mayor a cero"}

      not is_integer(ocupacion) or ocupacion < 0 ->
        {:error, "La ocupación actual no puede ser negativa"}

      ocupacion > capacidad_maxima ->
        {:error, "La ocupación actual no puede superar la capacidad máxima del albergue"}

      true ->
        :ok
    end
  end

  def a_map(%__MODULE__{} = albergue), do: serializar(albergue)

  def desde_map(mapa) when is_map(mapa) do
    with {:ok, atributos} <- normalizar(mapa),
         :ok <- validar_ids(atributos),
         {:ok, albergue} <- construir(atributos) do
      {:ok, albergue}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de albergue inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El albergue debe ser un mapa válido"}

  defp serializar(entidad) do
    entidad
    |> Map.from_struct()
    |> Map.new(fn {campo, valor} -> {Atom.to_string(campo), valor} end)
  end

  defp normalizar(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    Enum.reduce_while(mapa, {:ok, %{}}, fn {clave, valor}, {:ok, acc} ->
      campo =
        if is_atom(clave), do: clave, else: Enum.find(campos, &(Atom.to_string(&1) == clave))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, valor)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(clave)}"}}
    end)
  end

  defp validar_ids(atributos) do
    if texto?(atributos[:id]) and texto?(atributos[:codigo_albergue]),
      do: :ok,
      else: {:error, "ID y código de albergue son obligatorios"}
  end

  defp texto?(valor), do: is_binary(valor) and String.trim(valor) != ""

  defp construir(atributos) do
    {:ok, struct!(__MODULE__, atributos)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de albergue: #{Exception.message(error)}"}
  end
end
