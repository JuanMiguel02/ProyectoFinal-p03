defmodule EmergenciaServiciosTest do
  use ExUnit.Case
  doctest Emergencia.Servicios.ServicioTerritorio
  doctest Emergencia.Servicios.ServicioRecursos
  doctest Emergencia.Servicios.ServicioMascotas

  alias Emergencia.EstadoTerritorio
  alias Emergencia.EstadoRecursos
  alias Emergencia.EstadoMascotas
  alias Emergencia.EstadoMensajes
  alias Emergencia.MensajeDestinatario
  alias Emergencia.Necesidad
  alias Emergencia.Persona

  alias Emergencia.Servicios.{
    ServicioTerritorio,
    ServicioRecursos,
    ServicioMascotas,
    ServicioComunicacion
  }

  describe "MensajeDestinatario" do
    test "genera un código público y permite confirmar con ese código" do
      assert {:ok, {_mensaje, [destinatario]}, estado} =
               ServicioComunicacion.enviar_mensaje(
                 %EstadoMensajes{},
                 "USR-1",
                 "Estoy bien",
                 ["PER-1"]
               )

      assert destinatario.codigo == "MDE-0001"

      assert {:ok, {_segundo_mensaje, [segundo_destinatario]}, _estado} =
               ServicioComunicacion.enviar_mensaje(
                 estado,
                 "USR-1",
                 "Otro aviso",
                 ["PER-2"]
               )

      assert segundo_destinatario.codigo == "MDE-0002"

      assert {:ok, entregado, _estado_actualizado} =
               ServicioComunicacion.confirmar_entrega(estado, destinatario.codigo)

      assert entregado.codigo == destinatario.codigo
      assert entregado.estado == :entregado
      assert %DateTime{} = entregado.fecha_entrega
    end

    test "restaura destinatarios antiguos sin código" do
      id = "15564ab5-67da-4a14-9e88-d9f1fb002c4e"

      assert {:ok, destinatario} =
               MensajeDestinatario.desde_map(%{
                 "id_mensaje_destinatario" => id,
                 "id_envio" => "envio-1",
                 "id_persona" => "persona-1",
                 "fecha_entrega" => nil,
                 "estado" => "pendiente"
               })

      assert destinatario.codigo == "MDE-" <> String.upcase(id)
    end
  end

  describe "Necesidad" do
    test "requiere responsable y destinatario, e informa el tipo de entidad asociada" do
      opciones = [
        id_responsable: "USR-1",
        id_destinatario: "PER-1",
        entidad_asociada: "persona"
      ]

      assert {:ok, necesidad} =
               Necesidad.nueva("NEC-1", :agua, 10, "ZON-1", :alta, opciones)

      assert necesidad.id_responsable == "USR-1"
      assert necesidad.id_destinatario == "PER-1"
      assert necesidad.entidad_asociada == "persona"
      refute Map.has_key?(Map.from_struct(necesidad), :tipo_destinatario)

      assert {:error, "La necesidad requiere responsable y destinatario válidos"} =
               Necesidad.nueva("NEC-2", :agua, 10, "ZON-1", :alta)
    end

    test "migra necesidades antiguas asociándolas a su zona" do
      assert {:ok, necesidad} =
               Necesidad.nueva(
                 "NEC-1",
                 :agua,
                 10,
                 "ZON-1",
                 :alta,
                 id_responsable: "USR-1",
                 id_destinatario: "PER-1",
                 entidad_asociada: "persona"
               )

      mapa =
        necesidad
        |> Necesidad.a_map()
        |> Map.merge(%{
          "id_responsable" => nil,
          "id_destinatario" => nil,
          "entidad_asociada" => nil,
          "tipo_destinatario" => "persona"
        })

      assert {:ok, migrada} = Necesidad.desde_map(mapa)
      assert migrada.id_responsable == "SISTEMA"
      assert migrada.id_destinatario == "ZON-1"
      assert migrada.entidad_asociada == "zona"
    end
  end

  describe "Persona" do
    test "permite pasar de sin_informacion a en_albergue" do
      assert {:ok, persona} =
               Persona.nueva("Ana", "PER-1", "123", "ZON-1", :sin_informacion)

      assert {:ok, persona_actualizada} = Persona.cambiar_estado(persona, :en_albergue)
      assert persona_actualizada.estado == :en_albergue
      assert [{:en_albergue, %DateTime{}} | _] = persona_actualizada.historial_estados
    end
  end

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
    test "registra una necesidad y asigna existencias directas de forma atómica" do
      estado = %EstadoRecursos{}

      assert {:ok, necesidad, estado} =
               ServicioRecursos.registrar_necesidad(
                 estado,
                 :agua,
                 50,
                 "zona_1",
                 :critica,
                 opciones_necesidad("zona_1")
               )

      assert {:ok, recurso, estado} =
               ServicioRecursos.registrar_recurso(
                 estado,
                 "Agua",
                 100,
                 "litros",
                 "centro_1"
               )

      assert {:ok, [asignacion], estado} =
               ServicioRecursos.asignar_a_necesidad(estado, necesidad.id, recurso.codigo, 40)

      assert asignacion.id_recurso == recurso.id
      assert estado.necesidades[necesidad.id].cantidad_pendiente == 10

      assert {:ok, [%{cantidad: 60, ubicacion: "centro_1"}]} =
               ServicioRecursos.listar_recursos(estado)

      assert Enum.any?(estado.movimientos, fn {_id, movimiento} ->
               movimiento.tipo_movimiento == :asignacion and movimiento.cantidad == 40
             end)
    end

    test "si falta stock no modifica necesidad ni existencias" do
      {:ok, necesidad, estado} =
        ServicioRecursos.registrar_necesidad(
          %EstadoRecursos{},
          :agua,
          100,
          "zona_1",
          :alta,
          opciones_necesidad("zona_1")
        )

      {:ok, _recurso, estado} =
        ServicioRecursos.registrar_recurso(
          estado,
          "Agua",
          30,
          "litros",
          "centro_1"
        )

      assert {:error, motivo} =
               ServicioRecursos.asignar_a_necesidad(
                 estado,
                 necesidad.id,
                 hd(Map.values(estado.recursos)).codigo,
                 100
               )

      assert motivo =~ "Existencias insuficientes"
      assert estado.necesidades[necesidad.id].cantidad_pendiente == 100

      assert {:ok, [%{cantidad: 30, ubicacion: "centro_1"}]} =
               ServicioRecursos.listar_recursos(estado)
    end
  end

  describe "ServicioRecursos - logística" do
    test "registra ingresos, filtra existencias y transfiere de forma atómica" do
      estado = %EstadoRecursos{}

      assert {:ok, recurso, estado} =
               ServicioRecursos.registrar_recurso(
                 estado,
                 "Agua",
                 60,
                 "litros",
                 "centro_acopio_1"
               )

      assert recurso.codigo == "REC-0001"

      assert {:ok, movimiento, estado} =
               ServicioRecursos.transferir_recurso(
                 estado,
                 recurso.codigo,
                 "centro_acopio_1",
                 "albergue_2",
                 30
               )

      assert movimiento.tipo_movimiento == :transferencia
      assert movimiento.id_recurso == recurso.id
      assert movimiento.ubicacion_origen == "centro_acopio_1"
      assert movimiento.ubicacion_destino == "albergue_2"

      assert {:ok, [%{cantidad: 30, ubicacion: "albergue_2"}]} =
               ServicioRecursos.listar_recursos(estado, %{ubicacion: "albergue_2"})

      assert {:ok, [%{cantidad: 30, ubicacion: "centro_acopio_1"}]} =
               ServicioRecursos.listar_recursos(estado, %{ubicacion: "centro_acopio_1"})
    end

    test "rechaza transferencias mayores al stock sin modificar el estado" do
      estado = %EstadoRecursos{}

      {:ok, _recurso, estado} =
        ServicioRecursos.registrar_recurso(estado, "Agua", 10, "litros", "origen")

      assert {:error, _} =
               ServicioRecursos.transferir_recurso(
                 estado,
                 hd(Map.values(estado.recursos)).codigo,
                 "origen",
                 "destino",
                 11
               )

      assert {:ok, [%{cantidad: 10, ubicacion: "origen"}]} =
               ServicioRecursos.listar_recursos(estado)
    end

    test "asigna recursos y conserva la asociación de la necesidad" do
      {:ok, necesidad, estado_logistica} =
        ServicioRecursos.registrar_necesidad(
          %EstadoRecursos{},
          :agua,
          20,
          "zona_1",
          :critica,
          opciones_necesidad("zona_1")
        )

      {:ok, _recurso, estado_logistica} =
        ServicioRecursos.registrar_recurso(
          estado_logistica,
          "Agua",
          20,
          "litros",
          "centro_acopio_1"
        )

      codigo_recurso = hd(Map.values(estado_logistica.recursos)).codigo

      {:ok, _movimiento, estado_logistica} =
        ServicioRecursos.transferir_recurso(
          estado_logistica,
          codigo_recurso,
          "centro_acopio_1",
          "centro_acopio_2",
          10
        )

      assert {:ok, asignaciones, estado_logistica} =
               ServicioRecursos.asignar_a_necesidad(
                 estado_logistica,
                 necesidad.id,
                 codigo_recurso,
                 12
               )

      assert length(asignaciones) == 2
      assert Enum.all?(asignaciones, &(&1.id_recurso != nil))
      assert estado_logistica.necesidades[necesidad.id].cantidad_pendiente == 8
      assert {:ok, existencias} = ServicioRecursos.listar_recursos(estado_logistica)

      assert Enum.find(existencias, &(&1.ubicacion == "centro_acopio_1")).cantidad == 0
      assert Enum.find(existencias, &(&1.ubicacion == "centro_acopio_2")).cantidad == 8
    end

    test "genera códigos consecutivos y lista el catálogo completo" do
      estado = %EstadoRecursos{}

      assert {:ok, primero, estado} =
               ServicioRecursos.registrar_recurso(estado, "Agua", 10, "litros", "CAC-1")

      assert {:ok, segundo, estado} =
               ServicioRecursos.registrar_recurso(estado, "Cobijas", 5, "unidades", "CAC-2")

      assert primero.codigo == "REC-0001"
      assert segundo.codigo == "REC-0002"

      assert {:ok, recursos} = ServicioRecursos.listar_todos_recursos(estado)
      assert Enum.map(recursos, & &1.codigo) == ["REC-0001", "REC-0002"]

      assert Enum.map(recursos, &{&1.cantidad, &1.ubicacion}) == [
               {10, "CAC-1"},
               {5, "CAC-2"}
             ]
    end
  end

  defp opciones_necesidad(id_zona) do
    [
      id_responsable: "SISTEMA",
      id_destinatario: id_zona,
      entidad_asociada: "zona"
    ]
  end

  # ============================================================================
  # Pruebas de Mascotas y Coincidencias
  # ============================================================================
  describe "ServicioMascotas" do
    test "registra reportes y encuentra coincidencias basadas en atributos" do
      estado_inicial = %EstadoMascotas{}

      # Registrar reporte de mascota perdida
      assert {:ok, perdida, est1} =
               ServicioMascotas.registrar_reporte(
                 estado_inicial,
                 :perdida,
                 "gato",
                 "blanco",
                 :pequeno,
                 "zona_1",
                 "usr_1"
               )

      # Registrar reporte de mascota encontrada con características coincidentes
      assert {:ok, encontrada, est2} =
               ServicioMascotas.registrar_reporte(
                 est1,
                 :encontrada,
                 "gato",
                 "blanco",
                 :pequeno,
                 "zona_1",
                 "usr_2"
               )

      # Buscar coincidencias para el reporte perdido
      assert {:ok, coincidencias} = ServicioMascotas.buscar_coincidencias(est2, perdida.id)
      assert length(coincidencias) == 1
      assert hd(coincidencias).id == encontrada.id
    end

    test "previene resolver dos veces un reporte de mascota" do
      estado_inicial = %EstadoMascotas{}

      {:ok, reporte, est1} =
        ServicioMascotas.registrar_reporte(
          estado_inicial,
          :perdida,
          "perro",
          "cafe",
          :grande,
          "zona_1",
          "usr_1"
        )

      # Primera resolución exitosa
      assert {:ok, _resuelto, est2} = ServicioMascotas.resolver_reporte(est1, reporte.id)

      # Intentar resolver nuevamente el mismo reporte
      assert {:error, motivo} = ServicioMascotas.resolver_reporte(est2, reporte.id)
      assert motivo =~ "ya ha sido resuelto"
    end
  end
end
