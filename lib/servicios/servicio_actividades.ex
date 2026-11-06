defmodule Emergencia.Servicios.ServicioActividad do
  alias Emergencia.Actividad

  @moduledoc """
  Gestiona el registro y consulta de actividades del sistema.
  """

  @doc """
  Registra una actividad y actualiza el estado global.

  Devuelve:
  {:ok, estado_actualizado}
  {:error, motivo}
  """
  def registrar(estado_global, id_usuario, accion, descripcion, opciones \\ []) do
    with :ok <- validar_usuario(estado_global, id_usuario),
         {:ok, actividad} <-
           Actividad.nueva(descripcion, accion, id_usuario, opciones) do
      actividades = Map.get(estado_global, :actividades, %{})

      nuevo_estado =
        Map.put(
          estado_global,
          :actividades,
          Map.put(actividades, actividad.id, actividad)
        )

      {:ok, nuevo_estado}
    end
  end

  @doc """
  Obtiene todas las actividades registradas.
  """
  def listar(estado_global) do
    estado_global
    |> Map.get(:actividades, %{})
    |> Map.values()
    |> Enum.sort_by(& &1.fecha, {:desc, DateTime})
  end

  @doc """
  Busca las actividades realizadas por un usuario.
  """
  def listar_por_usuario(estado_global, id_usuario) do
    estado_global
    |> listar()
    |> Enum.filter(&(&1.id_usuario == id_usuario))
  end

  @doc """
  Busca una actividad por su identificador.
  """
  def buscar(estado_global, id_actividad) do
    actividades = Map.get(estado_global, :actividades, %{})

    case Map.fetch(actividades, id_actividad) do
      {:ok, actividad} -> {:ok, actividad}
      :error -> {:error, "Actividad no encontrada"}
    end
  end

  defp validar_usuario(estado_global, id_usuario) do
    usuarios = Map.get(estado_global, :usuarios, %{})

    if Map.has_key?(usuarios, id_usuario) do
      :ok
    else
      {:error, "El usuario que realiza la actividad no existe"}
    end
  end
end
