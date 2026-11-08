defmodule Emergencia.Consola.MenuAutenticacion do
  @moduledoc """
  Gestiona la interfaz de consola para el registro de usuarios
  y la autenticación en el sistema.
  """
  alias Emergencia.Aplicacion.Autenticacion

  # ============================================================
  # 1. MENÚ DE AUTENTICACIÓN
  # ============================================================

  def mostrar do
    IO.puts("\n========== AUTENTICACIÓN ==========")
    IO.puts("1. Iniciar sesión")
    IO.puts("2. Registrarse")
    IO.puts("3. Salir")

    opcion = leer_texto("\nSeleccione una opción: ")

    case opcion do
      "1" -> iniciar()
      "2" ->
        registrar()
        mostrar()
      "3" ->
          IO.puts("\nHasta pronto.")
          mostrar()
       _ ->
          IO.puts("\nOpción no válida.")
          mostrar()
    end
  end

  # ============================================================
  # 2. INICIO DE SESIÓN
  # ============================================================
  def iniciar do
    IO.puts("\n========== INICIO DE SESIÓN ==========")

    nombre_usuario = leer_texto("Nombre de usuario: ")
    contrasena = leer_texto("Contraseña: ")

    case Autenticacion.iniciar_sesion(nombre_usuario, contrasena) do
      {:ok, sesion} ->
        IO.puts("\nBienvenido, #{sesion.nombre_completo}")
        {:ok, sesion}

      {:ok, sesion, advertencia} ->
        IO.puts("\nBienvenido, #{sesion.nombre_completo}")
        mostrar_advertencia(advertencia)
        {:ok, sesion}

      {:error, motivo} ->
        IO.puts("\nNo se pudo iniciar sesión: #{inspect(motivo)}")
        {:error, motivo}
    end
  end

  # ============================================================
  # 3. REGISTRO PÚBLICO
  # ============================================================

  def registrar do
     IO.puts("\n========== REGISTRO DE USUARIO ==========")

    nombre_usuario = leer_texto("Nombre de usuario: ")
    contrasena = leer_texto("Contraseña: ")
    nombre_completo = leer_texto("Nombre completo: ")

    tipo = seleccionar_tipo_usuario()

    case tipo do
      nil ->
        IO.puts("\nTipo de usuario no válido.")
        {:error, :tipo_invalido}

      tipo ->
        case Autenticacion.registrar_usuario(
               nombre_usuario,
               contrasena,
               nombre_completo,
               tipo
             ) do

          {:ok, usuario} ->
            IO.puts("\nUsuario registrado correctamente.")
            IO.puts("Código de usuario: #{usuario.codigo_usuario}")
            {:ok, usuario}

          {:ok, usuario, advertencia} ->
            IO.puts("\nUsuario registrado correctamente.")
            IO.puts("Código de usuario: #{usuario.codigo_usuario}")
            mostrar_advertencia(advertencia)
            {:ok, usuario}

          {:error, motivo} ->
            IO.puts("\nNo se pudo registrar el usuario: #{inspect(motivo)}")
            {:error, motivo}
        end
    end
  end

  # ============================================================
  # 4. SELECCIÓN DEL TIPO DE USUARIO
  # ============================================================

  defp seleccionar_tipo_usuario do
    IO.puts("\nSeleccione el tipo de usuario:")
    IO.puts("1. Ciudadano")
    IO.puts("2. Voluntario")

    case leer_texto("Opción: ") do
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
        IO.puts("\nSesión cerrada correctamente.")
        :ok

      {:ok, advertencia} ->
        IO.puts("\nSesión cerrada correctamente.")
        mostrar_advertencia(advertencia)
        :ok

      {:error, motivo} ->
        IO.puts("\nNo se pudo cerrar la sesión: #{inspect(motivo)}")
        {:error, motivo}
    end
  end

  # ============================================================
  # 6. FUNCIONES AUXILIARES
  # ============================================================

  defp leer_texto(mensaje) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  defp mostrar_advertencia({:advertencia, motivo}) do
    IO.puts("\nAdvertencia: #{inspect(motivo)}")
  end

  defp mostrar_advertencia(motivo) do
    IO.puts("\nAdvertencia: #{inspect(motivo)}")
  end

end
