defmodule Emergencia.Cliente.Sesion do
  @moduledoc """
  Representa la información de sesión disponible en el cliente.

  No contiene contraseñas ni información interna de los monitores
  del servidor.
  """

  @enforce_keys [
    :id_usuario,
    :codigo_usuario,
    :nombre_usuario,
    :nombre_completo,
    :tipo_usuario
  ]

  defstruct [
    :id_usuario,
    :codigo_usuario,
    :nombre_usuario,
    :nombre_completo,
    :tipo_usuario,
    :zona_principal_id
  ]

  @type t :: %__MODULE__{
          id_usuario: String.t(),
          codigo_usuario: String.t(),
          nombre_usuario: String.t(),
          nombre_completo: String.t(),
          tipo_usuario: atom(),
          zona_principal_id: String.t() | nil
        }
end
