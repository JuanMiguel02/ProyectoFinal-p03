defmodule Emergencia.Servicios.ServicioTerritorio do
  @moduledoc """
  Servicio puro para la gestión de zonas afectadas, sectores y centros de acopio.
  """
  alias Emergencia.{GeneradorID, Zona, Sector, CentroAcopio, PuntoAtencion}

  @doc """
  Registra una nueva zona afectada en el estado global.
  """
  def registrar_zona(estado_global, nombre, nivel, personas_estimadas, _id_usuario \\ "SISTEMA") do
    codigo_zona = GeneradorID.generar("ZON", estado_global.zonas, & &1.codigo_zona)

    with {:ok, nueva_zona} <- Zona.nueva(nombre, nivel, personas_estimadas, codigo_zona),
         :ok <- validar_unicidad_zona(estado_global.zonas, nueva_zona.codigo_zona) do
      nuevas_zonas = Map.put(estado_global.zonas, nueva_zona.id, nueva_zona)
      estado_actualizado = %{estado_global | zonas: nuevas_zonas}
      {:ok, nueva_zona, estado_actualizado}
    end
  end

  def buscar_zona(estado, identificador) do
  zonas = Map.values(estado.zonas)

  case Enum.find(zonas, fn zona ->
         zona.id == identificador or
           zona.codigo_zona == String.upcase(identificador)
       end) do
    nil ->
      {:error, "No se encontró una zona con el identificador '#{identificador}'"}

    zona ->
      {:ok, zona}
  end
end

  @doc """
  Registra un sector y lo asocia a una zona existente.
  """
  def registrar_sector(estado_global, id_zona, nombre, nivel, personas_afectadas, _id_usuario \\ "SISTEMA") do
    codigo_sector = GeneradorID.generar("SEC", estado_global.sectores, & &1.codigo_sector)

    with {:ok, zona} <- obtener_zona(estado_global.zonas, id_zona),
         {:ok, nuevo_sector} <- Sector.nuevo(nombre, codigo_sector, nivel, personas_afectadas) do

      nuevos_sectores = Map.put(estado_global.sectores, nuevo_sector.id, nuevo_sector)
      zona_actualizada = %{zona | sectores: [nuevo_sector | zona.sectores]}
      nuevas_zonas = Map.put(estado_global.zonas, zona.id, zona_actualizada)

      estado_actualizado = %{estado_global | zonas: nuevas_zonas, sectores: nuevos_sectores}
      {:ok, nuevo_sector, estado_actualizado}
    end
  end

  @doc """
  Calcula recursivamente las estadísticas acumuladas de personas afectadas en una zona.
  """
  def estadisticas_zona(estado_global, id_zona) do
    with {:ok, zona} <- obtener_zona(estado_global.zonas, id_zona) do
      total_afectados = calcular_afectados_recursivo(zona.sectores, 0)

      estadisticas = %{
        zona: zona.nombre,
        nivel_general: zona.nivel_afectacion,
        personas_estimadas_zona: zona.personas_estimadas,
        personas_afectadas_sectores: total_afectados,
        cantidad_sectores: length(zona.sectores)
      }
      {:ok, estadisticas}
    end
  end

  defp calcular_afectados_recursivo([], acumulado), do: acumulado
  defp calcular_afectados_recursivo([sector | resto], acumulado) do
    calcular_afectados_recursivo(resto, acumulado + sector.personas_afectadas)
  end

  defp obtener_zona(zonas, id_zona) do
    case Map.fetch(zonas, id_zona) do
      {:ok, zona} -> {:ok, zona}
      :error -> {:error, "La zona con ID '#{id_zona}' no existe"}
    end
  end

  defp validar_unicidad_zona(zonas, codigo) do
    existe = Enum.any?(Map.values(zonas), fn z -> z.codigo_zona == codigo end)
    if existe, do: {:error, "Ya existe una zona con ese código"}, else: :ok
  end

  @doc """
  Registra un Centro de Acopio y lo vincula a una zona existente.
  """
  def registrar_centro_acopio(estado_global, nombre, direccion, capacidad, id_zona) do
    codigo_centro = GeneradorID.generar("CAC", estado_global.centros_acopio, & &1.codigo_centro_acopio)

    with {:ok, _zona} <- obtener_zona(estado_global.zonas, id_zona),
         {:ok, centro} <- CentroAcopio.nuevo(nombre, codigo_centro, direccion, capacidad, id_zona) do

      nuevos_centros = Map.put(estado_global.centros_acopio, centro.id, centro)
      estado_actualizado = %{estado_global | centros_acopio: nuevos_centros}

      {:ok, centro, estado_actualizado}
    end
  end

  @doc """
  Registra un Punto de Atención y lo inyecta en la lista de puntos de un sector.
  """
  def registrar_punto_atencion(estado_global, id_sector, nombre, tipo, ubicacion, descripcion \\ nil) do
    codigo_punto = GeneradorID.generar("PAT", %{}, fn _ -> nil end)

    with {:ok, sector} <- obtener_sector(estado_global.sectores, id_sector),
         {:ok, punto} <- PuntoAtencion.nuevo(nombre, codigo_punto, tipo, ubicacion, descripcion) do

      # Insertamos el punto en la estructura del sector
      sector_actualizado = %{sector | puntos_atencion: [punto | sector.puntos_atencion]}

      # Actualizamos el mapa global de sectores
      nuevos_sectores = Map.put(estado_global.sectores, sector_actualizado.id, sector_actualizado)

      # Para mantener la consistencia, también actualizamos el sector dentro de su zona
      {:ok, zona} = obtener_zona(estado_global.zonas, sector_actualizado.codigo_sector) # Asumiendo trazabilidad
      zona_actualizada = actualizar_sector_en_zona(zona, sector_actualizado)
      nuevas_zonas = Map.put(estado_global.zonas, zona_actualizada.id, zona_actualizada)

      estado_actualizado = %{estado_global | sectores: nuevos_sectores, zonas: nuevas_zonas}

      {:ok, punto, estado_actualizado}
    end
  end

  @doc """
  Devuelve la lista de todas las zonas registradas, ordenadas alfabéticamente.
  """
  def listar_zonas(estado_global) do
    zonas =
      estado_global.zonas
      |> Map.values()
      |> Enum.sort_by(& &1.nombre)

    {:ok, zonas}
  end

  @doc """
  Devuelve la lista de sectores pertenecientes a una zona específica.
  """
  def listar_sectores_por_zona(estado_global, id_zona) do
    case Map.fetch(estado_global.zonas, id_zona) do
      {:ok, zona} ->
        # Los sectores ya están anidados dentro del struct de Zona
        sectores_ordenados = Enum.sort_by(zona.sectores, & &1.nombre)
        {:ok, sectores_ordenados}

      :error ->
        {:error, "La zona con ID '#{id_zona}' no existe"}
    end
  end

  # Helpers privados necesarios para la consistencia
  defp obtener_sector(sectores, id_sector) do
    case Map.fetch(sectores, id_sector) do
      {:ok, sector} -> {:ok, sector}
      :error -> {:error, "El sector con ID '#{id_sector}' no existe"}
    end
  end

  defp actualizar_sector_en_zona(zona, sector_actualizado) do
    sectores_nuevos = Enum.map(zona.sectores, fn s ->
      if s.id == sector_actualizado.id, do: sector_actualizado, else: s
    end)
    %{zona | sectores: sectores_nuevos}
  end
end
