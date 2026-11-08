defmodule Emergencia.Consola.MenuAutenticacion do
  @moduledoc """
  Gestiona la interfaz de consola para el registro de usuarios
  y la autenticación en el sistema.
  """
  alias Emergencia.Aplicacion.Autenticacion
  alias Util

  # ============================================================
  # 1. MENÚ DE AUTENTICACIÓN
  # ============================================================

  def mostrar do
    Util.mostrar("\n========== AUTENTICACIÓN ==========", :mensaje)
    Util.mostrar("1. Iniciar sesión", :mensaje)
    Util.mostrar("2. Registrarse", :mensaje)
    Util.mostrar("3. Salir", :mensaje)

    opcion = Util.ingresar("\nSeleccione una opción: ", :texto)

    case opcion do
      "1" -> iniciar()
      "2" ->
        registrar()
        mostrar()
      "3" ->
          Util.mostrar("\nHasta pronto.", :mensaje)
          mostrar()
       _ ->
          Util.mostrar("\nOpción no válida.", :error)
          mostrar()
    end
  end

  # ============================================================
  # 2. INICIO DE SESIÓN
  # ============================================================
  def iniciar do
    Util.mostrar("\n========== INICIO DE SESIÓN ==========", :mensaje)

    nombre_usuario = Util.ingresar("Nombre de usuario: ", :texto)
    contrasena = Util.ingresar("Contraseña: ", :texto)

    case Autenticacion.iniciar_sesion(nombre_usuario, contrasena) do
      {:ok, sesion} ->
        Util.mostrar("\nBienvenido, #{sesion.nombre_completo}", :mensaje)
        {:ok, sesion}

      {:ok, sesion, advertencia} ->
        Util.mostrar("\nBienvenido, #{sesion.nombre_completo}", :mensaje)
        mostrar_advertencia(advertencia)
        {:ok, sesion}

      {:error, motivo} ->
        Util.mostrar("\nNo se pudo iniciar sesión: #{inspect(motivo)}", :error)
        {:error, motivo}
    end
  end

  # ============================================================
  # 3. REGISTRO PÚBLICO
  # ============================================================

  def registrar do
    Util.mostrar("\n========== REGISTRO DE USUARIO ==========", :mensaje)

    nombre_usuario = Util.ingresar("Nombre de usuario: ", :texto)
    contrasena = Util.ingresar("Contraseña: ", :texto)
    nombre_completo = Util.ingresar("Nombre completo: ", :texto)

    tipo = seleccionar_tipo_usuario()

    case tipo do
      nil ->
        Util.mostrar("\nTipo de usuario no válido.", :error)
        {:error, :tipo_invalido}

      tipo ->
        case Autenticacion.registrar_usuario(
               nombre_usuario,
               contrasena,
               nombre_completo,
               tipo
             ) do

          {:ok, usuario} ->
            Util.mostrar("\nUsuario registrado correctamente.", :mensaje)
            Util.mostrar("Código de usuario: #{usuario.codigo_usuario}", :mensaje)
            {:ok, usuario}

          {:ok, usuario, advertencia} ->
            Util.mostrar("\nUsuario registrado correctamente.", :mensaje)
            Util.mostrar("Código de usuario: #{usuario.codigo_usuario}", :mensaje)
            mostrar_advertencia(advertencia)
            {:ok, usuario}

          {:error, motivo} ->
            Util.mostrar("\nNo se pudo registrar el usuario: #{inspect(motivo)}", :error)
            {:error, motivo}
        end
    end
  end

  # ============================================================
  # 4. SELECCIÓN DEL TIPO DE USUARIO
  # ============================================================

  defp seleccionar_tipo_usuario do
    Util.mostrar("\nSeleccione el tipo de usuario:", :mensaje)
    Util.mostrar("1. Ciudadano", :mensaje)
    Util.mostrar("2. Voluntario", :mensaje)

    case Util.ingresar("Opción: ", :texto) do
      "1" -> :ciudadano
      "2" -> :voluntario
      _ -> nil
    end
  end

  # ============================================================
  # 5. CIERRE DE SESIÓN
  # ============================================================
  def cerrar(sesion) do
    case Autenticacion.cerrar_sesion(sesion) do
      :ok ->
        Util.mostrar("\nSesión cerrada correctamente.", :mensaje)
        :ok

      {:ok, advertencia} ->
        Util.mostrar("\nSesión cerrada correctamente.", :mensaje)
        mostrar_advertencia(advertencia)
        :ok

      {:error, motivo} ->
        Util.mostrar("\nNo se pudo cerrar la sesión: #{inspect(motivo)}", :error)
        {:error, motivo}
    end
  end

  # ============================================================
  # 6. FUNCIONES AUXILIARES
  # ============================================================

  defp mostrar_advertencia({:advertencia, motivo}) do
    Util.mostrar("\nAdvertencia: #{inspect(motivo)}", :error)
  end

  defp mostrar_advertencia(motivo) do
    Util.mostrar("\nAdvertencia: #{inspect(motivo)}", :error)
  end

end
