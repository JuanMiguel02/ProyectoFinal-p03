defmodule Emergencia.Usuario do
  @derive {Inspect, except: [:contrasena]}
  alias Emergencia.GeneradorID

  @tipos_permitidos [:ciudadano, :voluntario, :coordinador, :administrador]

  @enforce_keys [
    :id_usuario,
    :codigo_usuario,
    :nombre_usuario,
    :contrasena,
    :nombre_completo,
    :tipo_usuario
  ]

  defstruct [
    :id_usuario,
    :codigo_usuario,
    :nombre_usuario,
    :contrasena,
    :nombre_completo,
    :tipo_usuario,
    :zona_principal_id,
    conectado: false
  ]

  @type tipo_usuario :: :ciudadano | :voluntario | :coordinador | :administrador

  @type t :: %__MODULE__{
          id_usuario: String.t(),
          codigo_usuario: String.t(),
          nombre_usuario: String.t(),
          contrasena: String.t(),
          nombre_completo: String.t(),
          tipo_usuario: tipo_usuario(),
          zona_principal_id: String.t() | nil,
          conectado: boolean()
        }

  @doc """
  Función segura: Retorna {:ok, usuario} o {:error, motivo}.
  Por defecto, el usuario se crea desconectado.
  """
  def nuevo(username, contrasena, nombre_completo, tipo, zona_id \\ nil) do
    if tipo in @tipos_permitidos do
      {:ok,
       %__MODULE__{
         id_usuario: GeneradorID.generar_uuid(),
         codigo_usuario: GeneradorID.generar("USR"),
         nombre_usuario: username,
         contrasena: contrasena,
         nombre_completo: nombre_completo,
         tipo_usuario: tipo,
         zona_principal_id: zona_id,
         conectado: false
       }}
    else
      {:error, "Tipo de usuario no válido"}
    end
  end

  @doc """
  Convierte un usuario en un mapa preparado para JSON.
  """
  def a_map(%__MODULE__{} = usuario) do
    usuario
    |> Map.from_struct()
    |> Map.update!(:tipo_usuario, &Atom.to_string/1)
    |> Map.new(fn {campo, valor} -> {Atom.to_string(campo), valor} end)
  end

  # ============================================================
  # RECONSTRUCCIÓN DESDE JSON
  # ============================================================

  @doc """
  Reconstruye un usuario existente desde un mapa JSON.
  Conserva su ID y código originales.
  """
  def desde_map(mapa) when is_map(mapa) do
    with {:ok, tipo_usuario} <- obtener_tipo(obtener(mapa, "tipo_usuario")),
         :ok <- validar_id(obtener(mapa, "id_usuario")),
         :ok <- validar_codigo(obtener(mapa, "codigo_usuario")),
         :ok <- validar_campos(mapa) do
      {:ok,
       %__MODULE__{
         id_usuario: obtener(mapa, "id_usuario"),
         codigo_usuario: obtener(mapa, "codigo_usuario"),
         nombre_usuario: obtener(mapa, "nombre_usuario"),
         contrasena: obtener(mapa, "contrasena"),
         nombre_completo: obtener(mapa, "nombre_completo"),
         tipo_usuario: tipo_usuario,
         zona_principal_id: obtener(mapa, "zona_principal_id"),
         conectado: false
       }}
    end
  end

  def desde_map(_), do: {:error, "El usuario debe ser un mapa válido"}

  # ============================================================
  # VALIDACIONES DE RECONSTRUCCIÓN
  # ============================================================

  defp obtener_tipo(tipo) do
    case tipo do
      "ciudadano" -> {:ok, :ciudadano}
      "voluntario" -> {:ok, :voluntario}
      "coordinador" -> {:ok, :coordinador}
      "administrador" -> {:ok, :administrador}
      _ -> {:error, "Tipo de usuario inválido"}
    end
  end

  defp validar_id(id) when is_binary(id) and id != "", do: :ok
  defp validar_id(_), do: {:error, "ID de usuario inválido"}

  defp validar_codigo(codigo) when is_binary(codigo) and codigo != "", do: :ok
  defp validar_codigo(_), do: {:error, "Código de usuario inválido"}

  defp validar_campos(mapa) do
    campos = [
      "nombre_usuario",
      "contrasena",
      "nombre_completo"
    ]

    if Enum.all?(campos, fn campo ->
         valor = obtener(mapa, campo)
         is_binary(valor) and String.trim(valor) != ""
       end) do
      :ok
    else
      {:error, "Faltan campos obligatorios del usuario"}
    end
  end

  defp obtener(mapa, campo),
    do: Map.get(mapa, campo, Map.get(mapa, String.to_existing_atom(campo)))
end
