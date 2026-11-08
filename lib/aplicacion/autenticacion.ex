defmodule Emergencia.Aplicacion.Autenticacion do
 @moduledoc """
  Coordina el registro de usuarios, inicio y cierre de sesión,
  autorización y auditoría de las operaciones de autenticación.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.UsuariosServidor
  alias Emergencia.ActividadesServidor

  # ============================================================
  #  INICIO DE SESIÓN
  # ============================================================
    def iniciar_sesion(nombre_usuario, contrasena) do
    with {:ok, usuario} <- UsuariosServidor.autenticar(nombre_usuario, contrasena) do

      sesion = %Sesion{
        id_usuario: usuario.id,
        codigo_usuario: usuario.codigo_usuario,
        nombre_usuario: usuario.nombre_usuario,
        nombre_completo: usuario.nombre_completo,
        tipo_usuario: usuario.tipo_usuario,
        zona_principal_id: usuario.zona_principal_id
      }

      registrar_con_advertencia(
        sesion,
        usuario.id,
        :inicio_sesion,
        "El usuario #{usuario.nombre_usuario} inició sesión"
      )
    end
  end

  # ============================================================
  #  CIERRE DE SESIÓN
  # ============================================================

  def cerrar_sesion(%Sesion{} = sesion) do
    case UsuariosServidor.cerrar_sesion() do
      :ok ->
        case registrar_actividad(
               sesion.id_usuario,
               :cierre_sesion,
               "El usuario #{sesion.nombre_usuario} cerró sesión"
             ) do

          {:ok, _actividad} -> :ok

          {:error, motivo} ->
            {:ok, {:advertencia, {:error_auditoria, motivo}}}
        end

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  def cerrar_sesion(_) do
    {:error, :sesion_invalida}
  end

  # ============================================================
  # AUTORIZACIÓN
  # ============================================================

  def autorizar(%Sesion{}, operacion) do
    UsuariosServidor.autorizar(operacion)
  end

  def autorizar(_, _) do
    {:error, :sesion_invalida}
  end

  # ============================================================
  #  FUNCIONES PRIVADAS DE AUDITORÍA
  # ============================================================

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case registrar_actividad(id_responsable, accion, descripcion) do
      {:ok, _actividad} ->
        {:ok, resultado}

      {:error, motivo} ->
        {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end

  defp registrar_actividad(id_usuario, accion, descripcion) do
    ActividadesServidor.registrar(
      id_usuario,
      accion,
      descripcion
    )
  end

end
