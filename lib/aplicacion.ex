
defmodule Emergencia.Application do
  use Application

  @impl true
  def start(_tipo, _argumentos) do
    hijos = [
      Emergencia.Supervisor
    ]

    opciones = [
      strategy: :one_for_one,
      name: Emergencia.Application.Supervisor
    ]

    Supervisor.start_link(hijos, opciones)
  end
end
