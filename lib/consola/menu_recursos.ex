defmodule Emergencia.Consola.MenuRecursos do
  alias Emergencia.Consola.Util
  alias Emergencia.RecursosServidor

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE RECURSOS ---", :titulo)
    Util.mostrar("1. Listar Inventarios Disponibles", :opcion)
    Util.mostrar("2. Listar Necesidades Registradas", :opcion)
    Util.mostrar("3. Volver al menú principal", :opcion)

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" ->
        case RecursosServidor.listar_inventarios() do
          {:ok, inventarios} ->
            Enum.each(inventarios, fn i ->
              Util.mostrar(" - [ID: #{i.id}] Ubicación: #{i.id_ubicacion} | Recurso: #{i.id_recurso} | Disp: #{i.cantidad_disponible}", :mensaje)
            end)
          _ -> Util.mostrar("Error al leer inventarios.", :error)
        end
        iniciar(sesion)

      "2" ->
        case RecursosServidor.listar_necesidades() do
          {:ok, necesidades} ->
            Enum.each(necesidades, fn n ->
              Util.mostrar(" - [#{n.codigo_necesidad}] Tipo: #{n.tipo} | Req: #{n.cantidad_requerida} | Pendiente: #{n.cantidad_pendiente} | Estado: #{n.estado}", :mensaje)
            end)
          _ -> Util.mostrar("Error al leer necesidades.", :error)
        end
        iniciar(sesion)

      "3" -> :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
