
defmodule Emergencia.Application do
  use Application

  @impl true
  def start(_tipo, _argumentos) do
    Emergencia.Supervisor.start_link([])
  end
end
