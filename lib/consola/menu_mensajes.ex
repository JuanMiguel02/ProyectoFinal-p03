defmodule Emergencia.Consola.MenuMensajes do
  alias Emergencia.Consola.Util
  alias Emergencia.MensajesServidor

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MENSAJES ---", :titulo)
    Util.mostrar("1. Ver historial de mensajes", :opcion)
    Util.mostrar("2. Enviar nuevo mensaje", :opcion)
    Util.mostrar("3. Volver al menú principal", :opcion)

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" ->
        case MensajesServidor.listar() do
          {:ok, mensajes} ->
            Enum.each(mensajes, fn m ->
              Util.mostrar(" [#{m.fecha}] De: #{m.remitente} Para: #{m.destinatario} -> #{m.contenido}", :mensaje)
            end)
          _ -> Util.mostrar("No hay mensajes registrados.", :error)
        end
        iniciar(sesion)

      "2" ->
        remitente = sesion.id
        destinatario = IO.gets("ID del destinatario (Familia/Persona): ") |> String.trim()
        contenido = IO.gets("Contenido del mensaje: ") |> String.trim()

        case MensajesServidor.enviar_mensaje(remitente, destinatario, contenido) do
          {:ok, _} -> Util.mostrar("Mensaje enviado con éxito.", :exito)
          {:error, msg} -> Util.mostrar("Error: #{msg}", :error)
        end
        iniciar(sesion)

      "3" -> :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
