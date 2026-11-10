defmodule Emergencia.Consola.MenuMascotas do
  alias Emergencia.Aplicacion.GestionMascotas

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MASCOTAS ---", :mensaje)
    Util.mostrar("1. Ver reportes (Pérdidas y Encontradas)", :mensaje)
    Util.mostrar("2. Ver coincidencias sugeridas", :mensaje)
    Util.mostrar("3. Confirmar una coincidencia", :mensaje)
    Util.mostrar("4. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        with {:ok, reportes} <- GestionMascotas.listar_reportes(sesion) do
          Enum.each(reportes, fn r ->
            Util.mostrar(
              " - [#{r.id}] #{r.tipo} | #{r.especie}, Color: #{r.color} | Estado: #{r.estado}",
              :mensaje
            )
          end)
        else
          {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "2" ->
        with {:ok, coincidencias} <- GestionMascotas.listar_coincidencias(sesion) do
          Enum.each(coincidencias, fn c ->
            Util.mostrar(
              " - [#{c.id}] Pérdida: #{c.id_reporte_perdida} <-> Encontrada: #{c.id_reporte_encontrada} | Estado: #{c.estado}",
              :mensaje
            )
          end)
        else
          {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "3" ->
        id_coincidencia = Util.ingresar("ID de la coincidencia a confirmar: ", :texto)

        case GestionMascotas.confirmar_coincidencia(sesion, id_coincidencia) do
          {:error, motivo} -> Util.mostrar("Error: #{inspect(motivo)}", :error)
          _ok -> Util.mostrar("Coincidencia confirmada. Los reportes fueron cerrados.", :mensaje)
        end

        iniciar(sesion)

      "4" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
