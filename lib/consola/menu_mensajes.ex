defmodule Emergencia.Consola.MenuMensajes do
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.Aplicacion.GestionPersonas
  alias Emergencia.MensajesServidor

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MENSAJES ---", :mensaje)
    Util.mostrar("1. Ver historial de mensajes", :mensaje)
    Util.mostrar("2. Enviar nuevo mensaje", :mensaje)
    Util.mostrar("3. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        with :ok <- Autenticacion.autorizar(sesion, :consultar_mensajes),
             {:ok, mensajes} <- MensajesServidor.listar() do
          Enum.each(mensajes, fn m ->
            Util.mostrar(" [#{m.fecha}] De: #{m.id_remitente} -> #{m.contenido}", :mensaje)
          end)
        else
          {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "2" ->
        documento = Util.ingresar("Documento de la persona destinataria: ", :texto)
        contenido = Util.ingresar("Contenido del mensaje: ", :texto)

        with :ok <- Autenticacion.autorizar(sesion, :enviar_mensaje),
             {:ok, [persona]} <- GestionPersonas.buscar_personas(sesion, documento: documento),
             {:ok, _} <-
               MensajesServidor.enviar_mensaje(sesion.id_usuario, contenido, [persona.id]) do
          Util.mostrar("Mensaje enviado con éxito.", :mensaje)
        else
          {:ok, _} -> Util.mostrar("No se encontró una única persona con ese documento.", :error)
          {:error, motivo} -> Util.mostrar("Error: #{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "3" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
