defmodule Emergencia.Consola.PermisosMenu do
  alias Emergencia.Aplicacion.Autenticacion
  alias Util

  def mostrar_opciones(sesion, opciones) do
    Enum.each(opciones, fn {opcion, descripcion, permiso} ->
      if is_nil(permiso) or autorizado?(sesion, permiso) do
        Util.mostrar("#{opcion}. #{descripcion}", :mensaje)
      end
    end)
  end

  defp autorizado?(sesion, permiso) do
    case Autenticacion.autorizar(sesion, permiso) do
      :ok ->
        true

      {:error, "Acceso denegado:" <> _motivo} ->
        false

      {:error, motivo} ->
        Util.mostrar("No se pudo verificar el permiso '#{permiso}': #{inspect(motivo)}", :error)
        false
    end
  end
end
