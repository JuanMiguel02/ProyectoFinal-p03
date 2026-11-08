defmodule Emergencia.Servicios.ServicioTerritorio do
  @moduledoc """
  Servicio puro para la gestión de zonas afectadas, sectores y centros de acopio.
  """
  alias Emergencia.{Zona, Sector}

  @doc """
  Registra una nueva zona afectada en el estado global.
  """
  def registrar_zona(estado_global, nombre, nivel, personas_estimadas, _id_usuario \\ "SISTEMA") do
    with {:ok, nueva_zona} <- Zona.nueva(nombre, nivel, personas_estimadas),
         :ok <- validar_unicidad_zona(estado_global.zonas, nueva_zona.codigo_zona) do
      nuevas_zonas = Map.put(estado_global.zonas, nueva_zona.id, nueva_zona)
      estado_actualizado = %{estado_global | zonas: nuevas_zonas}
      {:ok, nueva_zona, estado_actualizado}
    end
  end

  @doc """
  Registra un sector y lo asocia a una zona existente.
  """
  def registrar_sector(estado_global, id_zona, nombre, nivel, personas_afectadas, _id_usuario \\ "SISTEMA") do
    with {:ok, zona} <- obtener_zona(estado_global.zonas, id_zona),
         {:ok, nuevo_sector} <- Sector.nuevo(nombre, nivel, personas_afectadas) do

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
end
