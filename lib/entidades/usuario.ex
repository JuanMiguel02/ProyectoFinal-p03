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
  def nuevo(user, pass, nombre, tipo, zona_id \\ nil) do
    cond do
      is_nil(user) or is_nil(pass) or is_nil(nombre) ->
        {:error, "Usuario, contraseña y nombre son obligatorios"}

      tipo not in @tipos_permitidos ->
        {:error, "Tipo de usuario :#{tipo} inválido. Opciones: #{inspect(@tipos_permitidos)}"}

      true ->
        {:ok,
         %__MODULE__{
           id_usuario: GeneradorID.generar_uuid(),
           codigo_usuario: GeneradorID.generar("USR"),
           nombre_usuario: user,
           contrasena: pass,
           nombre_completo: nombre,
           tipo_usuario: tipo,
           zona_principal_id: zona_id,
           conectado: false
         }}
    end
  end

  @doc """
  Función estricta: Retorna la estructura o lanza ArgumentError.
  """
  def nuevo!(user, pass, nombre, tipo, zona_id \\ nil) do
    case nuevo(user, pass, nombre, tipo, zona_id) do
      {:ok, usuario} -> usuario
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end
end
