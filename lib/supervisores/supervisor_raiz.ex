defmodule Emergencia.Supervisor do
  use Supervisor

  def start_link(opciones \\ []) do
    Supervisor.start_link(
      __MODULE__,
      opciones,
      name: __MODULE__
    )
  end

  @impl true
  def init(_opciones) do
    hijos = [
      Emergencia.UsuariosServidor,
      Emergencia.MensajesServidor,
      Emergencia.ActividadesServidor,
      Emergencia.PoblacionServidor,
      Emergencia.TerritorioServidor,
      Emergencia.RecursosServidor,
      Emergencia.MascotasServidor
    ]

    Supervisor.init(hijos, strategy: :one_for_one)
  end
end
