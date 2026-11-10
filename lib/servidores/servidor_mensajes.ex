defmodule Emergencia.EstadoMensajes do
  defstruct mensajes: %{},
            mensajes_destinatarios: %{}
end

defmodule Emergencia.MensajesServidor do
  use GenServer

  alias Emergencia.EstadoMensajes
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioComunicacion

  # ============================================================================
  # 1. Inicio del servidor
  # ============================================================================

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  # ============================================================================
  # 2. API pública
  # ============================================================================

  @doc """
  Envía un mensaje a una o varias personas.
  """
  def enviar_mensaje(id_remitente, contenido, lista_ids_personas, opciones \\ []) do
    GenServer.call(
      __MODULE__,
      {:enviar_mensaje, id_remitente, contenido, lista_ids_personas, opciones}
    )
  end

  @doc """
  Confirma la entrega de un mensaje a una persona.
  """
  def confirmar_entrega(id_mensaje_destinatario) do
    GenServer.call(__MODULE__, {:confirmar_entrega, id_mensaje_destinatario})
  end

  @doc """
  Consulta los mensajes asociados a una persona.
  """
  def obtener_mensajes_persona(id_persona) do
    GenServer.call(__MODULE__, {:obtener_mensajes_persona, id_persona})
  end

  @doc """
  Consulta el estado de entrega de un mensaje.
  """
  def consultar_estado_envio(id_mensaje) do
    GenServer.call(__MODULE__, {:consultar_estado_envio, id_mensaje})
  end

  @doc "Lista todos los mensajes registrados"
  def listar do
    GenServer.call(__MODULE__, :listar)
  end

  # ============================================================================
  # 3. Callbacks de GenServer
  # ============================================================================

  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:mensajes) do
      {:ok, datos} ->
        estado = %EstadoMensajes{
          mensajes: Map.get(datos, :mensajes, %{}),
          mensajes_destinatarios:
            Map.get(datos, :mensajes_destinatarios, %{})
        }

        {:ok, estado}

      {:error, motivo} ->
        {:stop, {:error_cargando_mensajes, motivo}}
    end
  end

  @impl true
  def handle_call(:listar, _from, estado) do
    {:reply, {:ok, Map.values(estado.mensajes)}, estado}
  end

  # ============================================================================
  # 4. Enviar mensaje
  # ============================================================================

  @impl true
  def handle_call(
        {:enviar_mensaje, id_remitente, contenido, lista_ids_personas, opciones},
        _from,
        estado
      ) do
    case ServicioComunicacion.enviar_mensaje(
           estado,
           id_remitente,
           contenido,
           lista_ids_personas,
           opciones
         ) do
      {:ok, resultado, nuevo_estado} ->
        case persistir(nuevo_estado) do
          :ok ->
            {:reply, {:ok, resultado}, nuevo_estado}

          {:error, motivo} ->
            {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # ============================================================================
  # 5. Confirmar entrega
  # ============================================================================

  @impl true
  def handle_call(
        {:confirmar_entrega, id_mensaje_destinatario},
        _from,
        estado
      ) do
    case ServicioComunicacion.confirmar_entrega(
           estado,
           id_mensaje_destinatario
         ) do
      {:ok, registro_actualizado, nuevo_estado} ->
        case persistir(nuevo_estado) do
          :ok ->
            {:reply, {:ok, registro_actualizado}, nuevo_estado}

          {:error, motivo} ->
            {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # ============================================================================
  # 6. Consultar mensajes de una persona
  # ============================================================================

  @impl true
  def handle_call(
        {:obtener_mensajes_persona, id_persona},
        _from,
        estado
      ) do
    respuesta =
      ServicioComunicacion.obtener_mensajes_persona(estado, id_persona)

    {:reply, respuesta, estado}
  end

  # ============================================================================
  # 7. Consultar estado de envío
  # ============================================================================

  @impl true
  def handle_call(
        {:consultar_estado_envio, id_mensaje},
        _from,
        estado
      ) do
    respuesta =
      ServicioComunicacion.consultar_estado_envio(estado, id_mensaje)

    {:reply, respuesta, estado}
  end

  # ============================================================================
  # 8. Función privada de persistencia
  # ============================================================================

  defp persistir(%EstadoMensajes{} = estado) do
    datos = %{
      mensajes: estado.mensajes,
      mensajes_destinatarios: estado.mensajes_destinatarios
    }

    GestorDatos.guardar_dominio(datos, :mensajes)
  end
end
