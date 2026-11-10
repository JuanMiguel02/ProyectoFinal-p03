defmodule Emergencia.ConcurrenciaTest do
  use ExUnit.Case

  alias Emergencia.RecursosServidor
  alias Emergencia.Servicios.ServicioRecursos
  alias Emergencia.EstadoRecursos

  test "control de concurrencia: dos procesos compiten por el mismo inventario limitado" do
    # Prepara el estado inicial puro simulando el GenServer
    estado_inicial = %EstadoRecursos{}

    {:ok, necesidad1, e1} = ServicioRecursos.registrar_necesidad(estado_inicial, :agua, 50, "ZON-001", :alta)
    {:ok, necesidad2, e2} = ServicioRecursos.registrar_necesidad(e1, :agua, 50, "ZON-002", :critica)
    {:ok, recurso, e3} = ServicioRecursos.registrar_recurso(e2, "Agua", :agua, "litros")

    # Solo agregamos 50 litros en total al inventario
    {:ok, inventario, estado_listo} = ServicioRecursos.agregar_inventario(e3, "CAC-001", :centro_acopio, recurso.id, 50)

    # 2. Crea un proceso (agente) para simular el GenServer manteniendo el estado
    {:ok, pid} = Agent.start_link(fn -> estado_listo end)

    # Función simulada del handle_call del GenServer para asignar recursos
    intento_asignar = fn id_nec ->
      Agent.get_and_update(pid, fn estado_actual ->
        case ServicioRecursos.asignar_recurso(estado_actual, id_nec, inventario.id, 50, "USUARIO_TEST") do
          {:ok, asignacion, nuevo_est} -> {{:ok, asignacion}, nuevo_est}
          {:error, motivo} -> {{:error, motivo}, estado_actual}
        end
      end)
    end

    # 3. Lanza dos procesos concurrentes al mismo milisegundo compitiendo por los 50 litros
    tarea1 = Task.async(fn -> intento_asignar.(necesidad1.id) end)
    tarea2 = Task.async(fn -> intento_asignar.(necesidad2.id) end)

    resultado1 = Task.await(tarea1)
    resultado2 = Task.await(tarea2)

    # 4. Verificar que el sistema manejó el conflicto correctamente
    resultados = [resultado1, resultado2]

    # Uno debió ser exitoso
    assert Enum.any?(resultados, fn res -> match?({:ok, _}, res) end)

    # El otro debió fallar por inventario insuficiente, gracias al cuello de botella de OTP
    assert Enum.any?(resultados, fn res -> match?({:error, "Inventario insuficiente" <> _}, res) end)

    # El inventario final nunca debe ser negativo (debe ser 0)
    estado_final = Agent.get(pid, & &1)
    inv_final = Map.get(estado_final.inventarios, inventario.id)
    assert inv_final.cantidad_disponible == 0
  end
end
