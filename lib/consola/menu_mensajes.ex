defmodule Emergencia.Consola.MenuMensajes do
  alias Emergencia.Aplicacion.GestionMensajes
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MENSAJES ---", :mensaje)
    Util.mostrar("1. Ver historial de mensajes", :mensaje)
    Util.mostrar("2. Enviar nuevo mensaje", :mensaje)
    Util.mostrar("3. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        case GestionMensajes.listar_mensajes(sesion) do
          {:ok, mensajes} ->
            Enum.each(mensajes, fn m ->
              Util.mostrar(" [#{m.fecha}] De: #{m.id_remitente} -> #{m.contenido}", :mensaje)
            end)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "2" ->
        destinatario = Util.ingresar("ID o Documento del destinatario (Familia/Persona): ", :texto)
        contenido = Util.ingresar("Contenido del mensaje: ", :texto)

        case GestionMensajes.enviar_mensaje(sesion, destinatario, contenido) do
          {:ok, _} -> Util.mostrar("Mensaje enviado con éxito.", :mensaje)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "3" -> :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
