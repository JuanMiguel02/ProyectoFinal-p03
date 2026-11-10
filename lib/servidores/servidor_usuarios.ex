defmodule Emergencia.EstadoUsuarios do
  @moduledoc false

  defstruct usuarios: %{},
            sesiones: %{}
end

defmodule Emergencia.UsuariosServidor do
  use GenServer

  alias Emergencia.EstadoUsuarios
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioUsuario

  # ============================================================
  # INTERFAZ PÚBLICA
  # ============================================================

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar(nombre_usuario, contrasena, nombre_completo, tipo, opciones \\ []) do
    GenServer.call(
      __MODULE__,
      {:registrar, nombre_usuario, contrasena, nombre_completo, tipo, opciones}
    )
  end

  def autenticar(nombre_usuario, contrasena) do
    GenServer.call(__MODULE__, {:autenticar, nombre_usuario, contrasena})
  end

  def autorizar(operacion) do
    GenServer.call(__MODULE__, {:autorizar, operacion})
  end

  def cerrar_sesion do
    GenServer.call(__MODULE__, :cerrar_sesion)
  end

  # ============================================================
  # INICIALIZACIÓN
  # ============================================================

  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:usuarios) do
      {:ok, %{usuarios: usuarios}} ->
        estado = %EstadoUsuarios{
          usuarios: usuarios,
          sesiones: %{}
        }

        case ServicioUsuario.validar_usuarios_cargados(Map.values(usuarios)) do
          :ok ->
            {:ok, estado}

          {:error, motivo} ->
            {:stop, motivo}
        end

      {:error, motivo} ->
        {:stop, motivo}
    end
  end

  # ============================================================
  # REGISTRO
  # ============================================================

  @impl true
  def handle_call(
        {:registrar, nombre_usuario, contrasena, nombre_completo, tipo, opciones},
        _from,
        estado
      ) do
    case ServicioUsuario.registrar(
           estado,
           nombre_usuario,
           contrasena,
           nombre_completo,
           tipo,
           opciones
         ) do
      {:ok, usuario, nuevo_estado} ->
        case GestorDatos.guardar_coleccion(
               %{usuarios: nuevo_estado.usuarios},
               :usuarios
             ) do
          :ok ->
            {:reply, {:ok, usuario}, nuevo_estado}

          {:error, motivo} ->
            {:reply, {:error, {:error_persistencia, motivo}}, estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  # ============================================================
  # AUTENTICACIÓN
  # ============================================================

  @impl true
  def handle_call({:autenticar, nombre_usuario, contrasena}, from, estado) do
    pid_cliente = elem(from, 0)

    case ServicioUsuario.autenticar(
           estado,
           nombre_usuario,
           contrasena
         ) do
      {:ok, usuario, nuevo_estado} ->
        if Map.has_key?(estado.sesiones, usuario.id) do
          {:reply, {:error, :usuario_ya_conectado}, estado}
        else
          monitor = Process.monitor(pid_cliente)

          sesion = %{
            pid: pid_cliente,
            nodo: node(pid_cliente),
            monitor: monitor
          }

          sesiones =
            Map.put(nuevo_estado.sesiones, usuario.id, sesion)

          nuevo_estado = %{nuevo_estado | sesiones: sesiones}

          {:reply, {:ok, usuario}, nuevo_estado}
        end

      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call(:cerrar_sesion, from, estado) do
    pid_cliente = elem(from, 0)

    case Enum.find(estado.sesiones, fn {_id, sesion} ->
           sesion.pid == pid_cliente
         end) do
      {id_usuario, sesion} ->
        case ServicioUsuario.desconectar(estado, id_usuario) do
          {:ok, _usuario, estado_actualizado} ->
            Process.demonitor(sesion.monitor, [:flush])

            sesiones =
              Map.delete(estado_actualizado.sesiones, id_usuario)

            nuevo_estado = %{
              estado_actualizado
              | sesiones: sesiones
            }

            {:reply, :ok, nuevo_estado}

          {:error, motivo} ->
            {:reply, {:error, motivo}, estado}
        end

      nil ->
        {:reply, {:error, :sesion_no_encontrada}, estado}
    end
  end

  @impl true
  def handle_call({:autorizar, operacion}, {pid, _tag}, estado) do
    sesion =
      Enum.find(estado.sesiones, fn {_id_usuario, datos_sesion} ->
        datos_sesion.pid == pid
      end)

    respuesta =
      case sesion do
        {id_usuario, _datos_sesion} ->
          case Map.fetch(estado.usuarios, id_usuario) do
            {:ok, usuario} ->
              ServicioUsuario.autorizar(usuario, operacion)

            :error ->
              {:error, :usuario_no_encontrado}
          end

        nil ->
          {:error, :sesion_no_autenticada}
      end

    {:reply, respuesta, estado}
  end

  @impl true
  def handle_info(
        {:DOWN, monitor, :process, _pid, _motivo},
        estado
      ) do
    case Enum.find(estado.sesiones, fn {_id, sesion} ->
           sesion.monitor == monitor
         end) do
      {id_usuario, _sesion} ->
        case ServicioUsuario.desconectar(estado, id_usuario) do
          {:ok, _usuario, estado_actualizado} ->
            sesiones =
              Map.delete(estado_actualizado.sesiones, id_usuario)

            nuevo_estado = %{
              estado_actualizado
              | sesiones: sesiones
            }

            {:noreply, nuevo_estado}

          {:error, _motivo} ->
            {:noreply, estado}
        end

      nil ->
        {:noreply, estado}
    end
  end
end
