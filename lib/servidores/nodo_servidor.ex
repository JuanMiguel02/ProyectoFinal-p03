defmodule Emergencia.NodoServidor do
  @moduledoc """
  Centraliza la comunicación con los procesos
  que administran el estado en el nodo servidor.
  """

  def configurar(nodo) do
    Application.put_env(
      :emergencia,
      :nodo_servidor,
      nodo
    )
  end

  def obtener_nodo do
    Application.get_env(
      :emergencia,
      :nodo_servidor,
      Node.self()
    )
  end

  def llamar(servidor, solicitud, tiempo \\ 5000) do
    GenServer.call(
      {servidor, obtener_nodo()},
      solicitud,
      tiempo
    )
  end
end
