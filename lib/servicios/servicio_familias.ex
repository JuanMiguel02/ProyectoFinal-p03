defmodule Emergencia.Servicios.ServicioFamilia do
  @moduledoc """
  Servicio puro para la gestión de familias y la consulta
  de sus integrantes.
  """

  alias Emergencia.Familia
  alias Emergencia.EstadoPoblacion
  alias Emergencia.GeneradorID

  # ============================================================================
  # Registro de familias
  # ============================================================================

  def registrar(%EstadoPoblacion{} = estado, nombre) do
    codigo_familia = GeneradorID.generar("FAM", estado.familias, & &1.codigo_familia)
    with {:ok, familia} <- Familia.nueva(nombre, codigo_familia) do
      nuevas_familias = Map.put(estado.familias, familia.id, familia)

      nuevo_estado = %{estado | familias: nuevas_familias}

      {:ok, familia, nuevo_estado}
    end
  end

  # ============================================================================
  # Buscar familia
  # ============================================================================

  def buscar_familia(%EstadoPoblacion{} = estado, id_o_codigo) do
    familia =
      Enum.find(Map.values(estado.familias), fn familia ->
        familia.id == id_o_codigo or familia.codigo_familia == id_o_codigo
      end)

    case familia do
      nil -> {:error, "No se encontró la familia"}
      familia -> {:ok, familia}
    end
  end

  # ============================================================================
  # Listar familias
  # ============================================================================

  def listar_familias(%EstadoPoblacion{} = estado) do
    familias =
      estado.familias
      |> Map.values()
      |> Enum.sort_by(& &1.nombre)

    {:ok, familias}
  end

  # ============================================================================
  # Consultar integrantes
  # ============================================================================

  def consultar_integrantes(%EstadoPoblacion{} = estado, id_o_codigo_familia) do
    with {:ok, familia} <- buscar_familia(estado, id_o_codigo_familia) do
      integrantes =
        estado.personas
        |> Map.values()
        |> Enum.filter(fn persona -> persona.id_familia == familia.id end)

      {:ok, integrantes}
    end
  end
end
