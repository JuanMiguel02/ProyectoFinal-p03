defmodule Emergencia.Aplicacion.GestionMensajes do
  @moduledoc """
  Coordina el envío de mensajes familiares y la consulta de notificaciones.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.MensajesServidor
  alias Emergencia.PoblacionServidor
  alias Emergencia.ActividadesServidor


  def enviar_mensaje(sesion, doc_id_o_familia, contenido, opciones \\ [])
  def enviar_mensaje(%Sesion{} = sesion, doc_id_o_familia, contenido, opciones) do
    with :ok <- Autenticacion.autorizar(sesion, :despachar_mensaje) do
      ids_personas =
        case PoblacionServidor.consultar_integrantes(doc_id_o_familia) do
          {:ok, integrantes} when integrantes != [] ->
            Enum.map(integrantes, & &1.id)
          _ ->
            [resolver_id_persona(doc_id_o_familia)]
        end

      case MensajesServidor.enviar_mensaje(sesion.id_usuario, contenido, ids_personas, opciones) do
        {:ok, resultado} ->
          registrar_con_advertencia(
            resultado,
            sesion.id_usuario,
            :enviar_mensaje,
            "El usuario #{sesion.nombre_usuario} envió un mensaje familiar"
          )
        error -> error
      end
    end
  end

  def enviar_mensaje(_, _, _, _), do: {:error, :sesion_invalida}

  def listar_mensajes(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas) do
      MensajesServidor.listar()
    end
  end

  def listar_mensajes(_), do: {:error, :sesion_invalida}

  def obtener_mensajes_persona(%Sesion{} = sesion, doc_o_id) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas) do
      id_pers = resolver_id_persona(doc_o_id)
      MensajesServidor.obtener_mensajes_persona(id_pers)
    end
  end

  def obtener_mensajes_persona(_, _), do: {:error, :sesion_invalida}

  defp resolver_id_persona(entrada) do
    case PoblacionServidor.buscar_personas([]) do
      {:ok, personas} ->
        encontrada = Enum.find(personas, fn p -> p.id == entrada or p.codigo_persona == entrada or p.documento == entrada end)
        if encontrada, do: encontrada.id, else: entrada
      _ -> entrada
    end
  end

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(id_responsable, accion, descripcion) do
      {:ok, _act} -> {:ok, resultado}
      {:error, motivo} -> {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end
