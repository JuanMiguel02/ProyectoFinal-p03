defmodule Emergencia.Aplicacion.Resolutor do
  @moduledoc """
  Traduce los identificadores que escribe el usuario (códigos cortos como
  `ZON-0001`, `REC-0001`, `NEC-0001`, documentos o UUIDs) al `id` interno
  de cada entidad.

  Pertenece a la capa de Aplicación: es la única que consulta a los
  servidores para resolver referencias, de modo que la capa de presentación
  (CLI / menús) nunca necesita conocerlos.

  Si no encuentra coincidencia devuelve la entrada sin modificar, para que
  sea el servidor quien produzca el error de dominio correspondiente.
  """

  alias Emergencia.TerritorioServidor
  alias Emergencia.RecursosServidor
  alias Emergencia.PoblacionServidor

  def zona(entrada) do
    case TerritorioServidor.listar_zonas() do
      {:ok, zonas} -> buscar(zonas, entrada, & &1.codigo_zona)
      _ -> entrada
    end
  end

  def recurso(entrada) do
    case RecursosServidor.listar_recursos() do
      {:ok, recursos} -> buscar(recursos, entrada, & &1.codigo_recurso)
      _ -> entrada
    end
  end

  def necesidad(entrada) do
    case RecursosServidor.listar_necesidades() do
      {:ok, necesidades} -> buscar(necesidades, entrada, & &1.codigo_necesidad)
      _ -> entrada
    end
  end

  def albergue(entrada) do
    case PoblacionServidor.listar_albergues() do
      {:ok, albergues} -> buscar(albergues, entrada, & &1.codigo)
      _ -> entrada
    end
  end

  def persona(entrada) do
    case PoblacionServidor.buscar_personas([]) do
      {:ok, personas} ->
        encontrada =
          Enum.find(personas, fn p ->
            p.id == entrada or p.codigo_persona == entrada or p.documento == entrada
          end)

        if encontrada, do: encontrada.id, else: entrada

      _ ->
        entrada
    end
  end

  @doc "Resuelve el id de una ubicación de inventario según su tipo."
  def ubicacion(entrada, :centro_acopio) do
    case TerritorioServidor.listar_centros_acopio() do
      {:ok, centros} -> buscar(centros, entrada, & &1.codigo_centro_acopio)
      _ -> entrada
    end
  end

  def ubicacion(entrada, :albergue), do: albergue(entrada)
  def ubicacion(entrada, _otro), do: zona(entrada)

  @doc """
  Resuelve un origen/destino de transferencia: devuelve `{id, tipo}` donde
  `tipo` es `:centro_acopio` o `:albergue`.
  """
  def ubicacion_transferencia(entrada) do
    centros = listar_o_vacio(TerritorioServidor.listar_centros_acopio())
    albergues = listar_o_vacio(PoblacionServidor.listar_albergues())

    centro = Enum.find(centros, &(&1.id == entrada or &1.codigo_centro_acopio == entrada))
    albergue = Enum.find(albergues, &(&1.id == entrada or &1.codigo == entrada))

    cond do
      centro ->
        {centro.id, :centro_acopio}

      albergue ->
        {albergue.id, :albergue}

      true ->
        id_zona = zona(entrada)
        if id_zona != entrada, do: {id_zona, :centro_acopio}, else: {entrada, :albergue}
    end
  end

  # ------------------------------------------------------------------
  # Auxiliares
  # ------------------------------------------------------------------

  defp listar_o_vacio({:ok, lista}), do: lista
  defp listar_o_vacio(_), do: []

  defp buscar(lista, entrada, fun_codigo) when is_list(lista) do
    case Enum.find(lista, fn e -> e.id == entrada or fun_codigo.(e) == entrada end) do
      nil -> entrada
      encontrado -> encontrado.id
    end
  end
end
