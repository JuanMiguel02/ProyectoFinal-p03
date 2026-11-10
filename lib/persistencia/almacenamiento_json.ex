defmodule Emergencia.Almacenamiento.JSON do
  @directorio "data"

  def guardar(archivo, datos) do
    ruta = Path.join(@directorio, archivo)
    temporal = ruta <> ".tmp"

    with :ok <- File.mkdir_p(@directorio),
         {:ok, contenido} <- Jason.encode(datos, pretty: true),
         :ok <- File.write(temporal, contenido),
         :ok <- File.rename(temporal, ruta) do
      :ok
    end
  end

  def cargar(archivo) do
    ruta = Path.join(@directorio, archivo)

    case File.read(ruta) do
      {:ok, contenido} -> Jason.decode(contenido)
      {:error, :enoent} -> {:ok, []}
      {:error, motivo} -> {:error, motivo}
    end
  end
end
