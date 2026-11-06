defmodule Emergencia.Servicios.ServicioComunicacion do
  @moduledoc """
  Servicio puro para la creación y despacho de mensajes, gestión de destinatarios,
  confirmación de entregas y consulta de notificaciones para personas afectadas.
  """
  alias Emergencia.Servicios.ServicioActividad
  # ============================================================================
  # 1. Enviar / Despachar Mensaje (Uno o múltiples destinatarios)
  # ============================================================================

  @doc """
  Crea un nuevo mensaje y sus correspondientes registros de entrega para una
  lista de IDs de personas destinatarias.
  """
  def enviar_mensaje(
        estado_global,
        id_remitente,
        contenido,
        lista_ids_personas,
        opciones \\ []
      ) do
    with :ok <- validar_destinatarios_existentes(estado_global.personas, lista_ids_personas),
         {:ok, nuevo_mensaje} <- Emergencia.Mensaje.nuevo(id_remitente, contenido, opciones),
         {:ok, destinatarios_map, lista_destinatarios} <-
           generar_destinatarios(nuevo_mensaje.id_envio, lista_ids_personas) do
      id_mensaje = nuevo_mensaje.id_envio
      nuevos_mensajes = Map.put(estado_global.mensajes, id_mensaje, nuevo_mensaje)
      nuevos_destinatarios = Map.merge(estado_global.mensajes_destinatarios, destinatarios_map)

      estado_actualizado = %{
        estado_global
        | mensajes: nuevos_mensajes,
          mensajes_destinatarios: nuevos_destinatarios
      }

      # Registro de auditoría
      total_dest = length(lista_ids_personas)
      desc = "Envío de mensaje '#{id_mensaje}' a #{total_dest} destinatarios"

      case ServicioActividad.registrar(
             estado_actualizado,
             id_remitente,
             "ENVIO_MENSAJE",
             desc
           ) do
        {:ok, estado_final} ->
          {:ok, {nuevo_mensaje, lista_destinatarios}, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  # ============================================================================
  # 2. Confirmación de Entrega
  # ============================================================================

  @doc """
  Actualiza el estado de entrega de un destinatario específico a :entregado
  registrando la estampa de tiempo actual.
  """
  def confirmar_entrega(estado_global, id_mensaje_destinatario, id_usuario_actualizador) do
    with {:ok, reg_destinatario} <-
           Map.fetch(estado_global.mensajes_destinatarios, id_mensaje_destinatario),
         {:ok, reg_actualizado} <-
           Emergencia.MensajeDestinatario.marcar_entregado(reg_destinatario) do
      nuevos_destinatarios =
        Map.put(estado_global.mensajes_destinatarios, id_mensaje_destinatario, reg_actualizado)

      estado_actualizado = %{estado_global | mensajes_destinatarios: nuevos_destinatarios}

      desc = "Confirmación de entrega de notificación '#{id_mensaje_destinatario}'"

      case ServicioActividad.registrar(
             estado_actualizado,
             id_usuario_actualizador,
             "CONFIRMAR_ENTREGA",
             desc
           ) do
        {:ok, estado_final} ->
          {:ok, reg_actualizado, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    else
      :error -> {:error, "El registro de entrega '#{id_mensaje_destinatario}' no existe"}
      {:error, motivo} -> {:error, motivo}
    end
  end

  # ============================================================================
  # 3. Consultas y Reportes de Mensajería
  # ============================================================================

  @doc """
  Retorna todas las notificaciones recibidas por una persona específica,
  junto con el mensaje original y el estado de entrega.
  """
  def obtener_mensajes_persona(estado_global, id_persona) do
    notificaciones =
      estado_global.mensajes_destinatarios
      |> Map.values()
      |> Enum.filter(&(&1.id_persona == id_persona))
      |> Enum.map(fn reg ->
        mensaje = Map.get(estado_global.mensajes, reg.id_envio)

        %{
          id_registro: reg.id_mensaje_destinatario,
          mensaje: mensaje,
          estado_entrega: reg.estado,
          fecha_entrega: reg.fecha_entrega
        }
      end)

    {:ok, notificaciones}
  end

  @doc """
  Genera un resumen métrico de un mensaje en específico (destinatarios totales,
  entregados y pendientes).
  """
  def consultar_estado_envio(estado_global, id_mensaje) do
    case Map.fetch(estado_global.mensajes, id_mensaje) do
      {:ok, mensaje} ->
        registros =
          estado_global.mensajes_destinatarios
          |> Map.values()
          |> Enum.filter(&(&1.id_envio == id_mensaje))

        pendientes = Enum.count(registros, &(&1.estado == :pendiente))
        entregados = Enum.count(registros, &(&1.estado == :entregado))

        resumen = %{
          mensaje: mensaje,
          total_destinatarios: length(registros),
          entregados: entregados,
          pendientes: pendientes
        }

        {:ok, resumen}

      :error ->
        {:error, "El mensaje con ID '#{id_mensaje}' no existe"}
    end
  end

  # ============================================================================
  # Funciones Privadas de Validación y Helper
  # ============================================================================

  defp validar_destinatarios_existentes(mapa_personas, lista_ids) do
    if Enum.empty?(lista_ids) do
      {:error, "La lista de destinatarios no puede estar vacía"}
    else
      inexistentes = Enum.reject(lista_ids, &Map.has_key?(mapa_personas, &1))

      if Enum.empty?(inexistentes) do
        :ok
      else
        {:error,
         "Las siguientes personas no existen en la base de datos: #{inspect(inexistentes)}"}
      end
    end
  end

  defp generar_destinatarios(id_mensaje, lista_ids) do
    resultados =
      Enum.map(lista_ids, fn id_persona ->
        Emergencia.MensajeDestinatario.nuevo(id_mensaje, id_persona, :pendiente)
      end)

    errores = Enum.filter(resultados, &match?({:error, _}, &1))

    if Enum.empty?(errores) do
      registros = Enum.map(resultados, fn {:ok, reg} -> reg end)
      mapa = Map.new(registros, fn reg -> {reg.id_mensaje_destinatario, reg} end)
      {:ok, mapa, registros}
    else
      {:error, "Error al generar destinatarios: #{inspect(errores)}"}
    end
  end
end
