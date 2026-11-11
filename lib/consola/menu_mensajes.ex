defmodule Emergencia.Consola.MenuMensajes do
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.Aplicacion.GestionMensajes
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MENSAJES ---", :mensaje)
    Util.mostrar("1. Ver historial de mensajes", :mensaje)
    Util.mostrar("2. Enviar mensaje a una persona o familia", :mensaje)
    Util.mostrar("3. Ver mensajes de una persona", :mensaje)
    Util.mostrar("4. Confirmar entrega por código", :mensaje)
    Util.mostrar("5. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        listar_mensajes(sesion)
        iniciar(sesion)

      "2" ->
        enviar_mensaje(sesion)
        iniciar(sesion)

      "3" ->
        listar_mensajes_persona(sesion)
        iniciar(sesion)

      "4" ->
        confirmar_entrega(sesion)
        iniciar(sesion)

      "5" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end

  defp listar_mensajes(sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_mensajes),
         {:ok, mensajes} <- GestionMensajes.listar_mensajes(sesion) do
      case mensajes do
        [] ->
          Util.mostrar("No hay mensajes registrados.", :mensaje)

        mensajes ->
          Enum.each(mensajes, fn mensaje ->
            Util.mostrar(
              "[#{mensaje.fecha}] De: #{mensaje.id_remitente} -> #{mensaje.contenido}",
              :mensaje
            )
          end)
      end
    else
      {:error, motivo} ->
        Util.mostrar("No se pudieron consultar mensajes: #{inspect(motivo)}", :error)
    end
  end

  defp enviar_mensaje(sesion) do
    destinatario =
      Util.ingresar("Documento/código de persona o código de familia: ", :texto)

    contenido = Util.ingresar("Contenido del mensaje: ", :texto)

    case GestionMensajes.enviar_mensaje(sesion, destinatario, contenido) do
      {:ok, {_mensaje, destinatarios}} ->
        codigos = Enum.map_join(destinatarios, ", ", & &1.codigo)
        Util.mostrar("Mensaje enviado. Código(s) de confirmación: #{codigos}", :mensaje)

      {:ok, {_mensaje, destinatarios}, {:advertencia, motivo}} ->
        codigos = Enum.map_join(destinatarios, ", ", & &1.codigo)
        Util.mostrar("Mensaje enviado. Código(s) de confirmación: #{codigos}", :mensaje)
        Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

      {:error, motivo} ->
        Util.mostrar("No se pudo enviar el mensaje: #{inspect(motivo)}", :error)
    end
  end

  defp listar_mensajes_persona(sesion) do
    identificador = Util.ingresar("Documento o código de la persona: ", :texto)

    case GestionMensajes.obtener_mensajes_persona(sesion, identificador) do
      {:ok, []} ->
        Util.mostrar("La persona no tiene mensajes.", :mensaje)

      {:ok, mensajes} ->
        Enum.each(mensajes, fn mensaje ->
          Util.mostrar(
            "[#{mensaje.codigo_registro}] #{mensaje.estado_entrega} | " <>
              "#{mensaje.mensaje.contenido}",
            :mensaje
          )
        end)

      {:error, motivo} ->
        Util.mostrar("No se pudieron consultar los mensajes: #{inspect(motivo)}", :error)
    end
  end

  defp confirmar_entrega(sesion) do
    codigo = Util.ingresar("Código de destinatario del mensaje: ", :texto)

    case GestionMensajes.confirmar_entrega(sesion, codigo) do
      {:ok, destinatario} ->
        Util.mostrar("Entrega #{destinatario.codigo} marcada como completada.", :mensaje)

      {:ok, destinatario, {:advertencia, motivo}} ->
        Util.mostrar("Entrega #{destinatario.codigo} confirmada.", :mensaje)
        Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

      {:error, motivo} ->
        Util.mostrar("No se pudo confirmar la entrega: #{inspect(motivo)}", :error)
    end
  end
end
