defmodule Emergencia.Consola.MenuMascotas do
  alias Emergencia.Consola.Util
  alias Emergencia.MascotasServidor

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MASCOTAS ---", :titulo)
    Util.mostrar("1. Ver reportes (Pérdidas y Encontradas)", :opcion)
    Util.mostrar("2. Ver coincidencias sugeridas", :opcion)
    Util.mostrar("3. Confirmar una coincidencia", :opcion)
    Util.mostrar("4. Volver al menú principal", :opcion)

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" ->
        case MascotasServidor.listar_reportes() do
          {:ok, reportes} ->
            Enum.each(reportes, fn r ->
              Util.mostrar(" - [#{r.id}] #{r.tipo} | #{r.especie}, Color: #{r.color} | Estado: #{r.estado}", :mensaje)
            end)
          _ -> Util.mostrar("No hay reportes.", :error)
        end
        iniciar(sesion)

      "2" ->
        case MascotasServidor.listar_coincidencias() do
          {:ok, coincidencias} ->
            Enum.each(coincidencias, fn c ->
              Util.mostrar(" - [ID Coincidencia: #{c.id}] Pérdida: #{c.id_reporte_perdida} <-> Encontrada: #{c.id_reporte_encontrada} | Estado: #{c.estado}", :mensaje)
            end)
          _ -> Util.mostrar("No hay coincidencias.", :error)
        end
        iniciar(sesion)

      "3" ->
        id_coincidencia = IO.gets("Ingrese el ID de la coincidencia a confirmar: ") |> String.trim()
        case MascotasServidor.confirmar_coincidencia(id_coincidencia, sesion.id) do
          {:ok, _, _} -> Util.mostrar("Coincidencia confirmada. Los reportes han sido cerrados en conjunto.", :exito)
          {:error, msg} -> Util.mostrar("Error: #{msg}", :error)
        end
        iniciar(sesion)

      "4" -> :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
