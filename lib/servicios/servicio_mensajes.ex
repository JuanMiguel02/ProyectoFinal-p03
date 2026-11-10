defmodule Emergencia.Servicios.ServicioComunicacion do
  @moduledoc """
  Servicio puro para la creación y despacho de mensajes, gestión de destinatarios,
  confirmación de entregas y consulta de notificaciones.
  """

  alias Emergencia.{EstadoMensajes, GeneradorID, Mensaje, MensajeDestinatario}

  # ============================================================================
  # 1. Enviar mensajes
  # ============================================================================

  @doc """
  Crea un mensaje y sus registros de destinatarios.

  Los IDs de las personas deben haber sido obtenidos y validados previamente
  por el dominio de población.
  """
  def enviar_mensaje(
        %EstadoMensajes{} = estado,
        id_remitente,
        contenido,
        lista_ids_personas,
        opciones \\ []
      ) do
    with :ok <- validar_destinatarios(lista_ids_personas),
         {:ok, nuevo_mensaje} <- Mensaje.nuevo(id_remitente, contenido, opciones),
         {:ok, destinatarios_map, lista_destinatarios} <-
           generar_destinatarios(
             nuevo_mensaje.id_envio,
             lista_ids_personas,
             estado.mensajes_destinatarios
           ) do
      nuevo_estado = %{
        estado
        | mensajes: Map.put(estado.mensajes, nuevo_mensaje.id_envio, nuevo_mensaje),
          mensajes_destinatarios: Map.merge(estado.mensajes_destinatarios, destinatarios_map)
      }

      {:ok, {nuevo_mensaje, lista_destinatarios}, nuevo_estado}
    end
  end

  # ============================================================================
  # 2. Confirmar entrega
  # ============================================================================

  @doc """
  Marca un registro de destinatario como entregado.
  """
  def confirmar_entrega(%EstadoMensajes{} = estado, id_mensaje_destinatario) do
    with {:ok, registro} <-
           obtener_destinatario(estado.mensajes_destinatarios, id_mensaje_destinatario),
         {:ok, registro_actualizado} <-
           MensajeDestinatario.marcar_entregado(registro) do
      nuevo_estado = %{
        estado
        | mensajes_destinatarios:
            Map.put(
              estado.mensajes_destinatarios,
              registro.id_mensaje_destinatario,
              registro_actualizado
            )
      }

      {:ok, registro_actualizado, nuevo_estado}
    end
  end

  # ============================================================================
  # 3. Consultar mensajes de una persona
  # ============================================================================

  @doc """
  Retorna los mensajes asociados a una persona, junto con su estado de entrega.
  """
  def obtener_mensajes_persona(%EstadoMensajes{} = estado, id_persona) do
    notificaciones =
      estado.mensajes_destinatarios
      |> Map.values()
      |> Enum.filter(&(&1.id_persona == id_persona))
      |> Enum.map(fn registro ->
        %{
          id_registro: registro.id_mensaje_destinatario,
          codigo_registro: registro.codigo,
          mensaje: Map.get(estado.mensajes, registro.id_envio),
          estado_entrega: registro.estado,
          fecha_entrega: registro.fecha_entrega
        }
      end)
      |> Enum.reject(&is_nil(&1.mensaje))

    {:ok, notificaciones}
  end

  # ============================================================================
  # 4. Consultar estado de un envío
  # ============================================================================

  @doc """
  Retorna un resumen del estado de entrega de un mensaje.
  """
  def consultar_estado_envio(%EstadoMensajes{} = estado, id_mensaje) do
    case Map.fetch(estado.mensajes, id_mensaje) do
      {:ok, mensaje} ->
        registros =
          estado.mensajes_destinatarios
          |> Map.values()
          |> Enum.filter(&(&1.id_envio == id_mensaje))

        pendientes = Enum.count(registros, &(&1.estado == :pendiente))
        entregados = Enum.count(registros, &(&1.estado == :entregado))

        {:ok,
         %{
           mensaje: mensaje,
           total_destinatarios: length(registros),
           entregados: entregados,
           pendientes: pendientes
         }}

      :error ->
        {:error, "El mensaje con ID '#{id_mensaje}' no existe"}
    end
  end

  # ============================================================================
  # 5. Funciones privadas
  # ============================================================================

  defp validar_destinatarios(lista_ids) when is_list(lista_ids) do
    cond do
      Enum.empty?(lista_ids) ->
        {:error, "La lista de destinatarios no puede estar vacía"}

      not Enum.all?(lista_ids, &(is_binary(&1) and String.trim(&1) != "")) ->
        {:error, "Todos los IDs de destinatarios deben ser válidos"}

      length(lista_ids) != length(Enum.uniq(lista_ids)) ->
        {:error, "La lista de destinatarios contiene IDs duplicados"}

      true ->
        :ok
    end
  end

  defp validar_destinatarios(_),
    do: {:error, "La lista de destinatarios debe ser válida"}

  defp generar_destinatarios(id_mensaje, lista_ids, existentes) do
    Enum.reduce_while(lista_ids, {:ok, %{}, []}, fn id_persona, {:ok, nuevos, registros} ->
      codigo =
        GeneradorID.generar(
          "MDE",
          Map.merge(existentes, nuevos),
          & &1.codigo
        )

      case MensajeDestinatario.nuevo(id_mensaje, id_persona, :pendiente, codigo: codigo) do
        {:ok, registro} ->
          nuevos = Map.put(nuevos, registro.id_mensaje_destinatario, registro)
          {:cont, {:ok, nuevos, [registro | registros]}}

        {:error, motivo} ->
          {:halt, {:error, motivo}}
      end
    end)
    |> case do
      {:ok, mapa, registros} -> {:ok, mapa, Enum.reverse(registros)}
      error -> error
    end
  end

  defp obtener_destinatario(mapa, identificador) do
    case Map.fetch(mapa, identificador) do
      {:ok, registro} ->
        {:ok, registro}

      :error ->
        case Enum.find(Map.values(mapa), &(&1.codigo == identificador)) do
          nil -> {:error, "No existe un registro de entrega con código '#{identificador}'"}
          registro -> {:ok, registro}
        end
    end
  end
end
