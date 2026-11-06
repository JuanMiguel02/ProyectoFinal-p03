defmodule Emergencia.Servicios.ServicioUsuario do
  @moduledoc """
  Servicio puro para la gestión de usuarios, autenticación, control de estado
  de conexión, autorización basada en roles y registro de auditoría.
  """

  @tipos_permitidos [:ciudadano, :voluntario, :coordinador, :administrador]

  # ============================================================================
  # 1. Registro de Usuarios
  # ============================================================================

  @doc """
  Registra un nuevo usuario en el sistema si el ID y el nombre de usuario son únicos.
  """
  def registrar_usuario(estado_global, id, nombre_usuario, contrasena, nombre_completo, id_zona \\ nil) do
    with :ok <- validar_unicidad_id(estado_global.usuarios, id),
        :ok <- validar_unicidad_nombre_usuario(estado_global.usuarios, nombre_usuario),
        {:ok, nuevo_usuario} <- Usuario.nuevo(id, nombre_usuario, contrasena, nombre_completo, tipo, id_zona: id_zona) do

         nuevos_usuarios = Map.put(estado_global.usuarios, id, nuevo_usuario)
         estado_actualizado = %{estado_global | usuarios: nuevo_usuarios}

         descripcion = "Usuario (#{id}) registrado exitosamente con rol:  #{tipo}"
         {:ok, estado_con_actividad} = ServicioActividad.registrar(estado_actualizado, id, "REGISTRO_USUARIO", descripcion)

        end
  end

  # ============================================================================
  # 2. Conexión y Autenticación (Login)
  # ============================================================================

  @doc """
  Autentica a un usuario verificando sus credenciales y actualizando su estado a conectado.
  """
  def autenticar(estado_global, nombre_usuario, contrasena) do
    with {:ok, usuario} <- buscar_por_usuario(estado_global.usuarios, nombre_usuario),
          :ok <- validar_contrasena(usuario, contrasena) do

           usuario_conectado =  %{usuario | conectado: true}
           nuevos_usuarios = Map.put(estado_global.usuarios, usuario.id, usuario_conectado)
           estado_actualizado = %{estado_global | usuarios: nuevos_usuarios}

           # Registro de auditoría
           descripcion = "Inicio de sesión exitoso desde el usuario '#{nombre_usuario}'"
           {:ok, estado_final} = ServicioActividad.registrar(estado_actualizado, usuario.id, "LOGIN",descripcion)

           {:ok, usuario_conectado, estado_final}

          end
  end

  # ============================================================================
  # 3. Desconexión (Logout)
  # ============================================================================

    @doc """
  Desconecta a un usuario activo cambiando su estado de conexión a false.
  """
  def desconectar(estado_global, id_usuario) do
    with {:ok, usuario} <- Map.fetch(estado_global.usuarios, id_usuario) do
      usuario_desconectado = %{usuario | conectado: false}
      nuevos_usuarios = Map.put(estado_global.usuarios, id_usuario, usuario_desconectado)
      estado_actualizado = %{estado_global | usuarios: nuevos_usuarios}

      # Registro de auditoría
      desc = "Cierre de sesión del usuario '#{usuario.nombre_usuario}'"
      {:ok, estado_final} = ServicioActividad.registrar(estado_actualizado, id_usuario, "LOGOUT", desc)

      {:ok, usuario_desconectado, estado_final}
    else
      :error -> {:error, "El usuario con ID #{id_usuario} no existe"}
    end
  end


  # ============================================================================
  # 4. Control de Permisos y Autorización (RBAC)
  # ============================================================================

  @doc """
  Evalúa si un usuario tiene autorización para realizar una operación específica
  según su tipo de usuario (Rol).
  """
  def autorizar(%Usuario{tipo: tipo}, operacion) do
    if permitido?(tipo, operacion) do
      :ok
    else
      {:error, "Acceso denegado: El rol :#{tipo} no tiene permiso para la operación '#{operacion}'"}
    end
  end

  # Matriz de Permisos por Rol usando Pattern Matching
  defp permitido?(:administrador, _operacion), do: true

  defp permitido?(:coordinador, operacion) when operacion in [
    :crear_zona, :crear_sector, :asignar_recursos, :despachar_mensaje,
    :registrar_persona, :ingreso_albergue, :salida_albergue,
    :crear_reporte_mascota, :crear_necesidad, :consultar_reportes
  ], do: true

  defp permitido?(:voluntario, operacion) when operacion in [
    :registrar_persona, :ingreso_albergue, :salida_albergue,
    :crear_reporte_mascota, :crear_necesidad, :consultar_reportes
  ], do: true

  defp permitido?(:ciudadano, operacion) when operacion in [
    :crear_reporte_mascota, :crear_necesidad, :consultar_reportes
  ], do: true

  defp permitido?(_tipo, _operacion), do: false

  # ============================================================================
  # Funciones Privadas de Validación
  # ============================================================================

  defp validar_unicidad_id(mapa_usuarios, id) do
    if Map.has_key?(mapa_usuarios, id) do
      {:error, "Ya existe un usuario registrado con el ID '#{id}'"}
    else
      :ok
    end
  end

  defp validar_unicidad_nombre_usuario(mapa_usuarios, nombre_usuario) do
    existe? = Enum.any?(mapa_usuarios, fn {_id, u} -> u.nombre_usuario == nombre_usuario end)

    if existe? do
      {:error, "El nombre de usuario '#{nombre_usuario}' ya está en uso"}
    else
      :ok
    end
  end

  defp buscar_por_nombre_usuario(mapa_usuarios,nombre_usuario) do
    case Enum.find(mapa_usuarios, fn {_id, u} -> u.nombre_usuario == nombre_usuario end) do
      {_id, usuario} -> {:ok, usuario}
      nil -> {:error, "Credenciales inválidas: usuario no encontrado"}
    end
  end

  defp validar_contrasena(usuario, contrasena) do
    if usuario.contrasena == contrasena do
      :ok
    else
      {:error, "Credenciales inválidas: contraseña incorrecta"}
    end
  end
end
