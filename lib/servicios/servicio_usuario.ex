defmodule Emergencia.Servicios.ServicioUsuario do
  @moduledoc """
  Servicio para la gestión de usuarios, autenticación,
  control de conexión, autorización y auditoría.
  """

  alias Emergencia.Usuario
  alias Emergencia.GeneradorID

  @tipos_permitidos [:ciudadano, :voluntario, :coordinador, :administrador]

  # ============================================================
  # 1. REGISTRO DE USUARIOS
  # ============================================================

  @doc """
  Registra un usuario si cumple las validaciones
  y su nombre de usuario e ID son únicos.
  """
  def registrar(estado, nombre_usuario, contrasena, nombre_completo, tipo, opciones \\ []) do
    id_zona = Keyword.get(opciones, :id_zona)
    codigo_usuario = GeneradorID.generar("USR", estado.usuarios, & &1.codigo_usuario)

    with :ok <- validar_id_no_proporcionado(opciones),
         :ok <- validar_nombre_usuario(nombre_usuario),
         :ok <- validar_contrasena(contrasena),
         :ok <- validar_nombre_completo(nombre_completo),
         :ok <- validar_tipo(tipo),
         :ok <- validar_unicidad_nombre_usuario(estado.usuarios, nombre_usuario),
         {:ok, nuevo_usuario} <- Usuario.nuevo(nombre_usuario, contrasena, nombre_completo, tipo, codigo_usuario, id_zona),
         :ok <- validar_unicidad_id(estado.usuarios, nuevo_usuario.id) do

      nuevos_usuarios = Map.put(estado.usuarios, nuevo_usuario.id, nuevo_usuario)

      nuevo_estado = %{estado | usuarios: nuevos_usuarios}

      {:ok, nuevo_usuario, nuevo_estado}
    end
  end

  # ============================================================
  # 2. AUTENTICACIÓN
  # ============================================================

  @doc """
  Autentica un usuario y actualiza su estado de conexión.
  """
  def autenticar(estado, nombre_usuario, contrasena) do
    with {:ok, usuario} <-
           buscar_por_nombre_usuario(estado.usuarios, nombre_usuario),
         :ok <- verificar_contrasena(usuario, contrasena) do
      usuario_conectado = %{usuario | conectado: true}

      nuevos_usuarios =
        Map.put(estado.usuarios, usuario.id, usuario_conectado)

      nuevo_estado = %{estado | usuarios: nuevos_usuarios}

      {:ok, usuario_conectado, nuevo_estado}
    end
  end

  # ============================================================
  # 3. DESCONEXIÓN
  # ============================================================

  @doc """
  Desconecta un usuario activo.
  """
  def desconectar(estado_global, id_usuario) do
    case Map.fetch(estado_global.usuarios, id_usuario) do
      {:ok, usuario} ->
        usuario_desconectado = %{usuario | conectado: false}
        nuevos_usuarios = Map.put(estado_global.usuarios, id_usuario, usuario_desconectado)
        estado_actualizado = %{estado_global | usuarios: nuevos_usuarios}

        {:ok, usuario_desconectado, estado_actualizado}

      :error ->
        {:error, "El usuario con ID '#{id_usuario}' no existe"}
    end
  end

  # ============================================================
  # 4. AUTORIZACIÓN
  # ============================================================

  @doc """
  Comprueba si un usuario puede realizar una operación.
  """
def autorizar(%Usuario{tipo_usuario: tipo}, operacion) do
  autorizar(tipo, operacion)
end

def autorizar(tipo, operacion) when tipo in @tipos_permitidos do
  if permitido?(tipo, operacion) do
    :ok
  else
    {:error,
     "Acceso denegado: el rol :#{tipo} no tiene permiso para '#{operacion}'"}
  end
end

def autorizar(_tipo, _operacion) do
  {:error, "Tipo de usuario no válido"}
end

# Administrador
defp permitido?(:administrador, _operacion), do: true

# Coordinador
defp permitido?(:coordinador, operacion)
     when operacion in [
            :crear_zona,
            :crear_sector,
            :asignar_recursos,
            :despachar_mensaje,

            :registrar_persona,
            :cambiar_estado_persona,
            :consultar_personas,

            :registrar_familia,
            :consultar_familias,
            :asignar_familia,

            :gestionar_albergues,
            :registrar_albergue,
            :ingreso_albergue,
            :salida_albergue,
            :consultar_albergues,

            :crear_reporte_mascota,
            :crear_necesidad,
            :consultar_reportes
          ],
     do: true

# Voluntario
defp permitido?(:voluntario, operacion)
     when operacion in [
            :registrar_persona,
            :cambiar_estado_persona,
            :consultar_personas,

            :registrar_familia,
            :consultar_familias,
            :asignar_familia,

            :ingreso_albergue,
            :salida_albergue,
            :consultar_albergues,

            :crear_reporte_mascota,
            :crear_necesidad,
            :consultar_reportes
          ],
     do: true

# Ciudadano
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
    ids = Enum.map(usuarios, & &1.id)

    nombre_usuarios =
      Enum.map(usuarios, fn usuario ->
        normalizar_nombre_usuario(usuario.nombre_usuario)
      end)

    cond do
      length(ids) != length(Enum.uniq(ids)) ->
        {:error, "Hay usuarios con IDs duplicados"}

      length(nombre_usuarios) != length(Enum.uniq(nombre_usuarios)) ->
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

  defp validar_nombre_usuario(nombre_usuario)
       when is_binary(nombre_usuario) do
    if String.trim(nombre_usuario) != "" do
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

  defp validar_unicidad_nombre_usuario(mapa_usuarios, nombre_usuario) do
    nombre_usuario_normalizado = normalizar_nombre_usuario(nombre_usuario)

    existe? =
      Enum.any?(mapa_usuarios, fn {_id, usuario} ->
        normalizar_nombre_usuario(usuario.nombre_usuario) == nombre_usuario_normalizado
      end)

    if existe? do
      {:error, "El nombre de usuario '#{nombre_usuario}' ya está en uso"}
    else
      :ok
    end
  end

  defp normalizar_nombre_usuario(nombre_usuario) do
    nombre_usuario
    |> String.trim()
    |> String.downcase()
  end

  # ============================================================
  # 7. BÚSQUEDA Y CONTRASEÑA
  # ============================================================

  defp buscar_por_nombre_usuario(mapa_usuarios, nombre_usuario) do
    nombre_usuario_normalizado = normalizar_nombre_usuario(nombre_usuario)

    case Enum.find(mapa_usuarios, fn {_id, usuario} ->
           normalizar_nombre_usuario(usuario.nombre_usuario) == nombre_usuario_normalizado
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
