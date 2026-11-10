defmodule Emergencia.Consola.MenuMascotas do
  alias Emergencia.Aplicacion.GestionMascotas
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MASCOTAS ---", :mensaje)
    Util.mostrar("1. Ver reportes (Pérdidas y Encontradas)", :mensaje)
    Util.mostrar("2. Registrar reporte de mascota", :mensaje)
    Util.mostrar("3. Ver coincidencias sugeridas", :mensaje)
    Util.mostrar("4. Confirmar una coincidencia", :mensaje)
    Util.mostrar("5. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        case GestionMascotas.listar_reportes(sesion) do
          {:ok, reportes} ->
            Enum.each(reportes, fn r ->
              Util.mostrar(" - [#{r.id}] #{r.tipo} | #{r.especie}, Color: #{r.color} | Estado: #{r.estado}", :mensaje)
            end)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "2" ->
        tipo = Util.ingresar("Tipo (perdida/encontrada): ", :texto)
        especie = Util.ingresar("Especie: ", :texto)
        nombre = Util.ingresar("Nombre (opcional): ", :texto)
        color = Util.ingresar("Color: ", :texto)
        tamano = Util.ingresar("Tamaño (pequeno/mediano/grande): ", :texto)
        zona = Util.ingresar("Código de la zona: ", :texto)
        contacto = Util.ingresar("Datos de contacto: ", :texto)
        opciones = if nombre != "", do: [nombre: nombre], else: []

        case GestionMascotas.registrar_reporte(sesion, String.to_atom(tipo), especie, color, String.to_atom(tamano), zona, contacto, opciones) do
          {:ok, r} -> Util.mostrar("Reporte registrado [ID: #{r.id}]", :mensaje)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "3" ->
        case GestionMascotas.listar_coincidencias(sesion) do
          {:ok, coincidencias} ->
            Enum.each(coincidencias, fn c ->
              Util.mostrar(" - [ID Coincidencia: #{c.id}] Pérdida: #{c.id_reporte_perdida} <-> Encontrada: #{c.id_reporte_encontrada} | Estado: #{c.estado}", :mensaje)
            end)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "4" ->
        id_coincidencia = Util.ingresar("Ingrese el ID de la coincidencia a confirmar: ", :texto)
        case GestionMascotas.confirmar_coincidencia(sesion, id_coincidencia) do
          {:ok, _, _} -> Util.mostrar("Coincidencia confirmada. Los reportes han sido cerrados en conjunto.", :mensaje)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "5" -> :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
