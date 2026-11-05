defmodule Emergencia.Recurso do
  @moduledoc """
  Define el catálogo maestro de recursos (ej. agua, medicamentos, cobijas)
  especificando su categoría, unidad de medida y conservando su historial de cambios.
  """

  @categorias_permitidas [:alimento, :medicina, :herramienta, :vestimenta, :equipo, :otro]

  @enforce_keys [:codigo, :nombre, :categoria, :unidad_medida]
  defstruct [:codigo, :nombre, :categoria, :unidad_medida, historial: []]

  @type categoria_recurso :: :alimento | :medicina | :herramienta | :vestimenta | :equipo | :otro
  @type t :: %__MODULE__{
          codigo: String.t(),
          nombre: String.t(),
          categoria: categoria_recurso(),
          unidad_medida: String.t(),
          historial: list()
        }

  @doc """
  Crea una nueva definición de Recurso validando sus atributos requeridos.
  """
  def nueva(codigo, nombre, categoria, unidad_medida, opciones \\ []) do
    with :ok <- validar_obligatorios(codigo, nombre, unidad_medida),
         :ok <- validar_enum(:categoria, categoria, @categorias_permitidas) do
      {:ok,
       %__MODULE__{
         codigo: codigo,
         nombre: nombre,
         categoria: categoria,
         unidad_medida: unidad_medida,
         historial: Keyword.get(opciones, :historial, [])
       }}
    end
  end

  @doc """
  Crea un nuevo Recurso o lanza ArgumentError si falla la validación.
  """
  def nueva!(codigo, nombre, categoria, unidad_medida, opciones \\ []) do
    case nueva(codigo, nombre, categoria, unidad_medida, opciones) do
      {:ok, recurso} -> recurso
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(codigo, nombre, unidad_medida) do
    if is_nil(codigo) or is_nil(nombre) or is_nil(unidad_medida) do
      {:error, "Código, nombre y unidad de medida son obligatorios"}
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
