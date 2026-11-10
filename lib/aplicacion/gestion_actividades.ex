defmodule Emergencia.Aplicacion.GestionActividades do
  @moduledoc """
  Consulta del registro de actividad de los usuarios.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.ActividadesServidor

  def listar(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_actividades) do
      ActividadesServidor.listar()
    end
  end

  def listar(_), do: {:error, :sesion_invalida}
end
