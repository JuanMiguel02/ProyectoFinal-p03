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

  def codigo_recurso(entrada) do
    case RecursosServidor.listar_recursos() do
      {:ok, recursos} ->
        case Enum.find(recursos, &(&1.codigo == entrada or &1.id == entrada)) do
          nil -> entrada
          recurso -> recurso.codigo
        end

      _ ->
        entrada
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

  def ubicacion_recurso(identificador) when is_binary(identificador) do
    with {:ok, centros} <- TerritorioServidor.listar_centros_acopio(),
         {:ok, zonas} <- TerritorioServidor.listar_zonas(),
         {:ok, albergues} <- PoblacionServidor.listar_albergues() do
      puntos =
        zonas
        |> Enum.flat_map(& &1.sectores)
        |> Enum.flat_map(& &1.puntos_atencion)

      case Enum.find(centros ++ puntos ++ albergues, &coincide_ubicacion?(&1, identificador)) do
        nil ->
          {:error, "No existe una ubicación registrada con el código o ID '#{identificador}'"}

        ubicacion ->
          {:ok, codigo_ubicacion(ubicacion)}
      end
    end
  end

  def ubicacion_recurso(_),
    do: {:error, "La ubicación debe ser el código o ID de un centro, punto o albergue"}

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

  def destinatario_necesidad(identificador) when is_binary(identificador) do
    with {:ok, personas} <- PoblacionServidor.buscar_personas([]),
         {:ok, familias} <- PoblacionServidor.listar_familias(),
         {:ok, albergues} <- PoblacionServidor.listar_albergues(),
         {:ok, centros} <- TerritorioServidor.listar_centros_acopio(),
         {:ok, zonas} <- TerritorioServidor.listar_zonas() do
      puntos =
        zonas
        |> Enum.flat_map(& &1.sectores)
        |> Enum.flat_map(& &1.puntos_atencion)

      destinatario =
        buscar_destinatario(personas, identificador, :persona, fn persona ->
          [persona.documento, persona.codigo_persona, persona.id]
        end) ||
          buscar_destinatario(familias, identificador, :familia, &[&1.codigo_familia, &1.id]) ||
          buscar_destinatario(albergues, identificador, :albergue, &[&1.codigo, &1.id]) ||
          buscar_destinatario(
            puntos,
            identificador,
            :punto_atencion,
            &[
              &1.codigo_punto_atencion,
              &1.id
            ]
          ) ||
          buscar_destinatario(
            centros,
            identificador,
            :centro_acopio,
            &[
              &1.codigo_centro_acopio,
              &1.id
            ]
          ) ||
          buscar_destinatario(zonas, identificador, :zona, &[&1.codigo_zona, &1.id])

      case destinatario do
        nil ->
          {:error,
           "No existe un destinatario registrado con el código o documento '#{identificador}'"}

        {id, tipo} ->
          {:ok, %{id: id, entidad_asociada: Atom.to_string(tipo)}}
      end
    end
  end

  def destinatario_necesidad(_),
    do: {:error, "El destinatario debe ser un código o documento registrado"}

  defp coincide_ubicacion?(ubicacion, identificador) do
    ubicacion.id == identificador or
      Enum.any?(
        codigos_ubicacion(ubicacion),
        &(String.upcase(&1) == String.upcase(identificador))
      )
  end

  defp codigos_ubicacion(%{codigo_centro_acopio: codigo}), do: [codigo]
  defp codigos_ubicacion(%{codigo_punto_atencion: codigo}), do: [codigo]
  defp codigos_ubicacion(%{codigo: codigo}), do: [codigo]

  defp codigo_ubicacion(%{codigo_centro_acopio: codigo}), do: codigo
  defp codigo_ubicacion(%{codigo_punto_atencion: codigo}), do: codigo
  defp codigo_ubicacion(%{codigo: codigo}), do: codigo

  # ------------------------------------------------------------------
  # Auxiliares
  # ------------------------------------------------------------------

  defp buscar(lista, entrada, fun_codigo) when is_list(lista) do
    case Enum.find(lista, fn e -> e.id == entrada or fun_codigo.(e) == entrada end) do
      nil -> entrada
      encontrado -> encontrado.id
    end
  end

  defp buscar_destinatario(lista, identificador, tipo, fun_identificadores) do
    case Enum.find(lista, fn entidad ->
           Enum.any?(fun_identificadores.(entidad), &coincide_identificador?(&1, identificador))
         end) do
      nil -> nil
      encontrado -> {encontrado.id, tipo}
    end
  end

  defp coincide_identificador?(valor, identificador)
       when is_binary(valor) and is_binary(identificador) do
    valor == identificador or String.upcase(valor) == String.upcase(identificador)
  end

  defp coincide_identificador?(_, _), do: false
end
