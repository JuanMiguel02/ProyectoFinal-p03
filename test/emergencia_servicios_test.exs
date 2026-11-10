defmodule EmergenciaServiciosTest do
  use ExUnit.Case
  doctest Emergencia.Servicios.ServicioTerritorio
  doctest Emergencia.Servicios.ServicioRecursos
  doctest Emergencia.Servicios.ServicioMascotas

  alias Emergencia.EstadoTerritorio
  alias Emergencia.EstadoRecursos
  alias Emergencia.EstadoMascotas
  alias Emergencia.Servicios.{ServicioTerritorio, ServicioRecursos, ServicioMascotas}

  # ============================================================================
  # Pruebas de Gestión Territorial
  # ============================================================================
  describe "ServicioTerritorio" do
    test "registra una zona correctamente y calcula estadísticas vacías" do
      estado_inicial = %EstadoTerritorio{zonas: %{}}

      assert {:ok, zona, nuevo_estado} =
               ServicioTerritorio.registrar_zona(estado_inicial, "Zona Sur", :alto, 500)

      assert zona.nombre == "Zona Sur"
      assert zona.nivel_afectacion == :alto
      assert zona.personas_estimadas == 500
      assert Map.has_key?(nuevo_estado.zonas, zona.id)

      # Probar estadísticas de zona sin sectores
      assert {:ok, stats} = ServicioTerritorio.estadisticas_zona(nuevo_estado, zona.id)
      assert stats.zona == "Zona Sur"
      assert stats.personas_estimadas_zona == 500
      assert stats.personas_afectadas_sectores == 0
      assert stats.cantidad_sectores == 0
    end
  end

  # ============================================================================
  # Pruebas de Recursos y Concurrencia / Disponibilidad
  # ============================================================================
  describe "ServicioRecursos" do
    test "registra necesidad, recurso y agrega inventario correctamente" do
      estado_inicial = %EstadoRecursos{}

      # 1. Registrar necesidad
      assert {:ok, necesidad, est1} =
               ServicioRecursos.registrar_necesidad(estado_inicial, :agua, 50, "zona_1", :critica)
      assert necesidad.cantidad_requerida == 50
      assert necesidad.estado == :pendiente

      # 2. Registrar recurso maestro
      assert {:ok, recurso, est2} =
               ServicioRecursos.registrar_recurso(est1, "Agua Potable", :alimento, "litros")
      assert recurso.codigo_recurso == "REC-0001"

      # 3. Agregar inventario (ingreso)
      assert {:ok, inventario, est3} =
               ServicioRecursos.agregar_inventario(est2, "centro_1", :centro_acopio, recurso.id, 100)
      assert inventario.cantidad_disponible == 100

      # 4. Asignar recurso con éxito (menor al inventario)
      assert {:ok, _asignacion, est4} =
               ServicioRecursos.asignar_recurso(est3, necesidad.id, inventario.id, 40)

      # Verificar que el inventario bajó a 60
      inv_actualizado = Map.get(est4.inventarios, inventario.id)
      assert inv_actualizado.cantidad_disponible == 60
    end

    test "impide asignar recursos si el inventario es insuficiente (Control de concurrencia lógica)" do
      estado_inicial = %EstadoRecursos{}

      {:ok, necesidad, est1} =
        ServicioRecursos.registrar_necesidad(estado_inicial, :medicina, 100, "zona_1", :alta)
      {:ok, recurso, est2} =
        ServicioRecursos.registrar_recurso(est1, "Analgésicos", :medicina, "pastillas")
      {:ok, inventario, est3} =
        ServicioRecursos.agregar_inventario(est2, "centro_1", :centro_acopio, recurso.id, 30)

      # Intentar asignar 100 cuando solo hay 30 disponibles
      assert {:error, motivo} =
               ServicioRecursos.asignar_recurso(est3, necesidad.id, inventario.id, 100)

      assert motivo =~ "Inventario insuficiente"
    end
  end

  # ============================================================================
  # Pruebas de Mascotas y Coincidencias
  # ============================================================================
  describe "ServicioMascotas" do
    test "registra reportes y encuentra coincidencias basadas en atributos" do
      estado_inicial = %EstadoMascotas{}

      # Registrar reporte de mascota perdida
      assert {:ok, perdida, est1} =
               ServicioMascotas.registrar_reporte(estado_inicial, :perdida, "gato", "blanco", :pequeno, "zona_1", "usr_1")

      # Registrar reporte de mascota encontrada con características coincidentes
      assert {:ok, encontrada, est2} =
               ServicioMascotas.registrar_reporte(est1, :encontrada, "gato", "blanco", :pequeno, "zona_1", "usr_2")

      # Buscar coincidencias para el reporte perdido
      assert {:ok, coincidencias} = ServicioMascotas.buscar_coincidencias(est2, perdida.id)
      assert length(coincidencias) == 1
      assert hd(coincidencias).id == encontrada.id
    end

    test "previene resolver dos veces un reporte de mascota" do
      estado_inicial = %EstadoMascotas{}

      {:ok, reporte, est1} =
        ServicioMascotas.registrar_reporte(estado_inicial, :perdida, "perro", "cafe", :grande, "zona_1", "usr_1")

      # Primera resolución exitosa
      assert {:ok, _resuelto, est2} = ServicioMascotas.resolver_reporte(est1, reporte.id)

      # Intentar resolver nuevamente el mismo reporte
      assert {:error, motivo} = ServicioMascotas.resolver_reporte(est2, reporte.id)
      assert motivo =~ "ya ha sido resuelto"
    end
  end
end
