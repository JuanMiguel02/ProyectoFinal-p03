
defmodule Emergencia.Aplicacion.GestionUsuarios do
  @moduledoc """
  Coordina el registro y la administración de las cuentas
  de usuario del sistema.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.UsuariosServidor
  alias Emergencia.ActividadesServidor

  # ============================================================
  # 1. REGISTRO PÚBLICO
  # ============================================================

  def registrar_usuario(nombre_usuario,contrasena, nombre_completo, tipo) when tipo in [:ciudadano, :voluntario] do

    case UsuariosServidor.registrar(nombre_usuario, contrasena, nombre_completo, tipo) do

      {:ok, usuario} ->
        registrar_con_advertencia(
          usuario,
          usuario.id,
          :registro_usuario,
          "El usuario #{usuario.codigo_usuario} creó su propia cuenta como #{tipo}"
        )

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  def registrar_usuario(_nombre_usuario,_contrasena, _nombre_completo, _tipo ) do
    {:error, :rol_no_permitido_para_autoregistro}
  end

  # ============================================================
  # 2. REGISTRO ADMINISTRATIVO
  # ============================================================

  def registrar_usuario(%Sesion{tipo_usuario: :administrador} = sesion, nombre_usuario, contrasena, nombre_completo, tipo) when tipo in [:ciudadano, :voluntario, :coordinador] do

    case UsuariosServidor.registrar(nombre_usuario,contrasena,nombre_completo,tipo) do

      {:ok, usuario} ->
        registrar_con_advertencia(
          usuario,
          sesion.id_usuario,
          :registro_usuario,
          "El administrador #{sesion.nombre_usuario} creó la cuenta " <>
            "#{usuario.codigo_usuario} con rol #{tipo}"
        )

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  def registrar_usuario(
        %Sesion{},
        _nombre_usuario,
        _contrasena,
        _nombre_completo,
        _tipo
      ) do
    {:error, :rol_no_permitido}
  end

  def registrar_usuario(
        _sesion,
        _nombre_usuario,
        _contrasena,
        _nombre_completo,
        _tipo
      ) do
    {:error, :sesion_invalida}
  end

  # ============================================================
  # 3. AUDITORÍA
  # ============================================================

  defp registrar_con_advertencia(
         resultado,
         id_responsable,
         accion,
         descripcion
       ) do

    case ActividadesServidor.registrar(
           id_responsable,
           accion,
           descripcion
         ) do

      {:ok, _actividad} ->
        {:ok, resultado}

      {:error, motivo} ->
        {:ok, resultado,
         {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end
