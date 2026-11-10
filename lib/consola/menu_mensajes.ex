defmodule Emergencia.Consola.MenuMensajes do
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.Aplicacion.GestionMensajes

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MENSAJES ---", :mensaje)
    Util.mostrar("1. Ver historial de mensajes", :mensaje)
    Util.mostrar("2. Enviar nuevo mensaje", :mensaje)
    Util.mostrar("3. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        with :ok <- Autenticacion.autorizar(sesion, :consultar_mensajes),
             {:ok, mensajes} <- GestionMensajes.listar_mensajes(sesion) do
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

        case GestionMensajes.enviar_mensaje(sesion, documento, contenido) do
          {:error, motivo} ->
            Util.mostrar("Error: #{inspect(motivo)}", :error)

          {:ok, {_mensaje, destinatarios}} ->
            codigos = Enum.map_join(destinatarios, ", ", & &1.codigo)

            Util.mostrar(
              "Mensaje enviado. Código(s) para confirmar entrega: #{codigos}",
              :mensaje
            )

          {:ok, {_mensaje, destinatarios}, {:advertencia, motivo}} ->
            codigos = Enum.map_join(destinatarios, ", ", & &1.codigo)
            Util.mostrar("Mensaje enviado. Código(s): #{codigos}", :mensaje)
            Util.mostrar("Advertencia: #{inspect(motivo)}", :error)
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
