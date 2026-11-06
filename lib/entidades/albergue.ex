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
  def nueva(codigo, nombre, id_zona, capacidad_maxima, opciones \\ []) do
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
  def nueva!(codigo, nombre, id_zona, capacidad_maxima, opciones \\ []) do
    case nueva(codigo, nombre, id_zona, capacidad_maxima, opciones) do
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
end
