
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
      Emergencia.MensajesServidor
    ]

    Supervisor.init(hijos, strategy: :one_for_one)
  end
end
