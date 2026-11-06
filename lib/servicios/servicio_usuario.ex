defmodule Emergencia.Servicios.ServicioUsuario do
  @moduledoc """
  Servicio para la gestión de usuarios, autenticación,
  control de conexión, autorización y auditoría.
  """

  alias Emergencia.Usuario
  alias Emergencia.Servicios.ServicioActividad

  @tipos_permitidos [:ciudadano, :voluntario, :coordinador, :administrador]

  # ============================================================
  # 1. REGISTRO DE USUARIOS
  # ============================================================

  @doc """
  Registra un usuario si cumple las validaciones
  y su nombre de usuario e ID son únicos.
  """
  def registrar_usuario(
        estado_global,
        username,
        contrasena,
        nombre_completo,
        tipo,
        opciones \\ []
      ) do
    id_zona = Keyword.get(opciones, :id_zona)

    with :ok <- validar_id_no_proporcionado(opciones),
         :ok <- validar_nombre_usuario(username),
         :ok <- validar_contrasena(contrasena),
         :ok <- validar_nombre_completo(nombre_completo),
         :ok <- validar_tipo(tipo),
         :ok <- validar_unicidad_nombre_usuario(estado_global.usuarios, username),
         {:ok, nuevo_usuario} <-
           Usuario.nuevo(username, contrasena, nombre_completo, tipo, id_zona),
         :ok <- validar_unicidad_id(estado_global.usuarios, nuevo_usuario.id_usuario) do
      id_final = nuevo_usuario.id_usuario

      nuevos_usuarios =
        Map.put(
          estado_global.usuarios,
          id_final,
          nuevo_usuario
        )

      estado_actualizado =
        %{estado_global | usuarios: nuevos_usuarios}

      descripcion =
        "Usuario '#{username}' registrado con ID #{id_final} y rol :#{tipo}"

      case ServicioActividad.registrar(
             estado_actualizado,
             id_final,
             "REGISTRO_USUARIO",
             descripcion
           ) do
        {:ok, estado_final} ->
          {:ok, nuevo_usuario, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  # ============================================================
  # 2. AUTENTICACIÓN
  # ============================================================

  @doc """
  Autentica un usuario y actualiza su estado de conexión.
  """
  def autenticar(estado_global, nombre_usuario, contrasena) do
    with {:ok, usuario} <-
           buscar_por_nombre_usuario(
             estado_global.usuarios,
             nombre_usuario
           ),
         :ok <- verificar_contrasena(usuario, contrasena) do
      usuario_conectado = %{usuario | conectado: true}

      nuevos_usuarios =
        Map.put(
          estado_global.usuarios,
          usuario.id_usuario,
          usuario_conectado
        )

      estado_actualizado =
        %{estado_global | usuarios: nuevos_usuarios}

      descripcion =
        "Inicio de sesión exitoso desde el usuario '#{nombre_usuario}'"

      case ServicioActividad.registrar(
             estado_actualizado,
             usuario.id_usuario,
             "LOGIN",
             descripcion
           ) do
        {:ok, estado_final} ->
          {:ok, usuario_conectado, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  # ============================================================
  # 3. DESCONEXIÓN
  # ============================================================

  @doc """
  Desconecta un usuario activo.
  """
  def desconectar(estado_global, id_usuario) do
    with {:ok, usuario} <-
           Map.fetch(estado_global.usuarios, id_usuario) do
      usuario_desconectado = %{usuario | conectado: false}

      nuevos_usuarios =
        Map.put(
          estado_global.usuarios,
          id_usuario,
          usuario_desconectado
        )

      estado_actualizado =
        %{estado_global | usuarios: nuevos_usuarios}

      descripcion =
        "Cierre de sesión del usuario '#{usuario.nombre_usuario}'"

      case ServicioActividad.registrar(
             estado_actualizado,
             id_usuario,
             "LOGOUT",
             descripcion
           ) do
        {:ok, estado_final} ->
          {:ok, usuario_desconectado, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    else
      :error ->
        {:error, "El usuario con ID #{id_usuario} no existe"}
    end
  end

  # ============================================================
  # 4. AUTORIZACIÓN
  # ============================================================

  @doc """
  Comprueba si un usuario puede realizar una operación.
  """
  def autorizar(%Usuario{tipo_usuario: tipo}, operacion) do
    if permitido?(tipo, operacion) do
      :ok
    else
      {:error, "Acceso denegado: el rol :#{tipo} no tiene permiso para '#{operacion}'"}
    end
  end

  defp permitido?(:administrador, _operacion), do: true

  defp permitido?(:coordinador, operacion)
       when operacion in [
              :crear_zona,
              :crear_sector,
              :asignar_recursos,
              :despachar_mensaje,
              :registrar_persona,
              :ingreso_albergue,
              :salida_albergue,
              :crear_reporte_mascota,
              :crear_necesidad,
              :consultar_reportes
            ],
       do: true

  defp permitido?(:voluntario, operacion)
       when operacion in [
              :registrar_persona,
              :ingreso_albergue,
              :salida_albergue,
              :crear_reporte_mascota,
              :crear_necesidad,
              :consultar_reportes
            ],
       do: true

  defp permitido?(:ciudadano, operacion)
       when operacion in [
              :crear_reporte_mascota,
              :crear_necesidad,
              :consultar_reportes
            ],
       do: true

  defp permitido?(_, _), do: false

  # ============================================================
  # 5. VALIDACIÓN DE USUARIOS CARGADOS DESDE JSON
  # ============================================================

  @doc """
  Comprueba que no existan IDs ni nombres de usuario duplicados
  en una lista de usuarios reconstruidos.
  """
  def validar_usuarios_cargados(usuarios) do
    ids = Enum.map(usuarios, & &1.id_usuario)

    usernames =
      Enum.map(usuarios, fn usuario ->
        normalizar_username(usuario.nombre_usuario)
      end)

    cond do
      length(ids) != length(Enum.uniq(ids)) ->
        {:error, "Hay usuarios con IDs duplicados"}

      length(usernames) != length(Enum.uniq(usernames)) ->
        {:error, "Hay nombres de usuario duplicados"}

      true ->
        :ok
    end
  end

  # ============================================================
  # 6. VALIDACIONES PRIVADAS
  # ============================================================

  defp validar_id_no_proporcionado(opciones) do
    if Keyword.has_key?(opciones, :id) do
      {:error, "El ID se genera automáticamente y no debe proporcionarse"}
    else
      :ok
    end
  end

  defp validar_nombre_usuario(username)
       when is_binary(username) do
    if String.trim(username) != "" do
      :ok
    else
      {:error, "El nombre de usuario no puede estar vacío"}
    end
  end

  defp validar_nombre_usuario(_),
    do: {:error, "El nombre de usuario debe ser texto"}

  defp validar_contrasena(contrasena)
       when is_binary(contrasena) do
    if String.trim(contrasena) != "" do
      :ok
    else
      {:error, "La contraseña no puede estar vacía"}
    end
  end

  defp validar_contrasena(_),
    do: {:error, "La contraseña debe ser texto"}

  defp validar_nombre_completo(nombre)
       when is_binary(nombre) do
    if String.trim(nombre) != "" do
      :ok
    else
      {:error, "El nombre completo no puede estar vacío"}
    end
  end

  defp validar_nombre_completo(_),
    do: {:error, "El nombre completo debe ser texto"}

  defp validar_tipo(tipo) do
    if tipo in @tipos_permitidos do
      :ok
    else
      {:error, "El tipo de usuario '#{tipo}' no es válido"}
    end
  end

  defp validar_unicidad_id(mapa_usuarios, id) do
    if Map.has_key?(mapa_usuarios, id) do
      {:error, "Ya existe un usuario con el ID '#{id}'"}
    else
      :ok
    end
  end

  defp validar_unicidad_nombre_usuario(mapa_usuarios, username) do
    username_normalizado = normalizar_username(username)

    existe? =
      Enum.any?(mapa_usuarios, fn {_id, usuario} ->
        normalizar_username(usuario.nombre_usuario) == username_normalizado
      end)

    if existe? do
      {:error, "El nombre de usuario '#{username}' ya está en uso"}
    else
      :ok
    end
  end

  defp normalizar_username(username) do
    username
    |> String.trim()
    |> String.downcase()
  end

  # ============================================================
  # 7. BÚSQUEDA Y CONTRASEÑA
  # ============================================================

  defp buscar_por_nombre_usuario(mapa_usuarios, username) do
    username_normalizado = normalizar_username(username)

    case Enum.find(mapa_usuarios, fn {_id, usuario} ->
           normalizar_username(usuario.nombre_usuario) == username_normalizado
         end) do
      {_id, usuario} ->
        {:ok, usuario}

      nil ->
        {:error, "Credenciales inválidas"}
    end
  end

  defp verificar_contrasena(usuario, contrasena) do
    if usuario.contrasena == contrasena do
      :ok
    else
      {:error, "Credenciales inválidas"}
    end
  end
end
