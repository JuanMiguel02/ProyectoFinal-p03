defmodule Emergencia.Consola.MenuMascotas do
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.MascotasServidor

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MASCOTAS ---", :mensaje)
    Util.mostrar("1. Ver reportes (Pérdidas y Encontradas)", :mensaje)
    Util.mostrar("2. Ver coincidencias sugeridas", :mensaje)
    Util.mostrar("3. Confirmar una coincidencia", :mensaje)
    Util.mostrar("4. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes),
             {:ok, reportes} <- MascotasServidor.listar_reportes() do
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
        with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes),
             {:ok, coincidencias} <- MascotasServidor.listar_coincidencias() do
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

        with :ok <- Autenticacion.autorizar(sesion, :confirmar_coincidencia),
             {:ok, _} <-
               MascotasServidor.confirmar_coincidencia(id_coincidencia, sesion.id_usuario) do
          Util.mostrar("Coincidencia confirmada. Los reportes fueron cerrados.", :mensaje)
        else
          {:error, motivo} -> Util.mostrar("Error: #{inspect(motivo)}", :error)
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
