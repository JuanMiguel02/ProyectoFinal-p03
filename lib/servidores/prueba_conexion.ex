defmodule Emergencias.PruebaConexion do
  @moduledoc """
  Permite automatizar la conexion entre los nodos
  usando el script de python
  """

  @intentos 15
  @espera 1000

  def verificar_sistema do
    case System.get_env("NODO_SERVIDOR") do
      nil ->
        IO.puts("ERROR: No se configuró NODO_SERVIDOR")

      nombre_nodo ->
        nodo_servidor = String.to_atom(nombre_nodo)

        IO.puts("\nConectando con el servidor...")
        conectar(nodo_servidor, @intentos)
    end
  end

  defp conectar(nodo_servidor, intentos) do
    case Node.connect(nodo_servidor) do
      true ->
        configurar_cliente(nodo_servidor)

      false when intentos > 1 ->
        IO.puts("Servidor todavía no disponible. Reintentando...")
        Process.sleep(@espera)
        conectar(nodo_servidor, intentos - 1)

      false ->
        IO.puts("ERROR: No fue posible conectar con el servidor.")

      :ignored ->
        IO.puts("ERROR: La conexión fue ignorada.")
    end
  end

  defp configurar_cliente(nodo_servidor) do
    Emergencia.NodoServidor.configurar(nodo_servidor)

    IO.puts("\nConexión establecida correctamente.")

    IO.inspect(Node.self(), label: "Nodo cliente")
    IO.inspect(nodo_servidor, label: "Nodo servidor")
    IO.inspect(Node.list(), label: "Nodos conectados")

    :ok
  end
end
