defmodule Emergencia.ConcurrenciaTest do
  use ExUnit.Case

  alias Emergencia.EstadoRecursos
  alias Emergencia.Servicios.ServicioRecursos

  test "dos transferencias simultáneas no superan las existencias directas" do
    {:ok, _recurso, estado} =
      ServicioRecursos.registrar_recurso(
        %EstadoRecursos{},
        "Agua",
        :agua,
        50,
        "litros",
        "centro_acopio_1"
      )

    {:ok, pid} = Agent.start_link(fn -> estado end)

    transferir = fn ->
      Agent.get_and_update(pid, fn estado_actual ->
        case ServicioRecursos.transferir_recurso(
               estado_actual,
               "REC-0001",
               "centro_acopio_1",
               "albergue_2",
               30
             ) do
          {:ok, movimiento, nuevo_estado} -> {{:ok, movimiento}, nuevo_estado}
          {:error, motivo} -> {{:error, motivo}, estado_actual}
        end
      end)
    end

    resultados =
      1..2
      |> Enum.map(fn _ -> Task.async(transferir) end)
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &match?({:error, _}, &1)) == 1

    {:ok, existencias} = Agent.get(pid, &ServicioRecursos.listar_recursos/1)
    assert Enum.sum(Enum.map(existencias, & &1.cantidad)) == 50
    assert Enum.find(existencias, &(&1.ubicacion == "centro_acopio_1")).cantidad == 20
    assert Enum.find(existencias, &(&1.ubicacion == "albergue_2")).cantidad == 30
  end

  test "asignaciones simultáneas actualizan stock y necesidad en una sola operación" do
    {:ok, necesidad1, estado} =
      ServicioRecursos.registrar_necesidad(
        %EstadoRecursos{},
        :agua,
        50,
        "zona_1",
        :critica,
        opciones_necesidad("zona_1")
      )

    {:ok, necesidad2, estado} =
      ServicioRecursos.registrar_necesidad(
        estado,
        :agua,
        50,
        "zona_2",
        :alta,
        opciones_necesidad("zona_2")
      )

    {:ok, _recurso, estado} =
      ServicioRecursos.registrar_recurso(
        estado,
        "Agua",
        :agua,
        50,
        "litros",
        "centro_1"
      )

    {:ok, pid} = Agent.start_link(fn -> estado end)

    asignar = fn necesidad ->
      Agent.get_and_update(pid, fn estado_actual ->
        case ServicioRecursos.asignar_a_necesidad(estado_actual, necesidad.id, "REC-0001", 50) do
          {:ok, asignaciones, nuevo_estado} -> {{:ok, asignaciones}, nuevo_estado}
          {:error, motivo} -> {{:error, motivo}, estado_actual}
        end
      end)
    end

    resultados =
      [necesidad1, necesidad2]
      |> Enum.map(&Task.async(fn -> asignar.(&1) end))
      |> Enum.map(&Task.await/1)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &match?({:error, _}, &1)) == 1

    estado_final = Agent.get(pid, & &1)
    assert Enum.sum(Map.values(estado_final.existencias)) == 0
    assert length(Map.values(estado_final.asignaciones)) == 1
  end

  defp opciones_necesidad(id_zona) do
    [
      id_responsable: "SISTEMA",
      id_destinatario: id_zona,
      entidad_asociada: "zona"
    ]
  end
end
