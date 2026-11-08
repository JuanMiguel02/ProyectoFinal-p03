defmodule Emergencia.Servicios.ServicioActividad do
  alias Emergencia.Actividad
  alias Emergencia.EstadoActividades

  @moduledoc """
  Gestiona el registro y consulta de actividades del sistema.
  """

  @doc """
  Registra una actividad y actualiza el estado global.

  Devuelve:
  {:ok, estado_actualizado}
  {:error, motivo}
  """
  def registrar(%EstadoActividades{} = estado, id_usuario, accion, descripcion, opciones \\ []) do
    with {:ok, actividad} <- Actividad.nueva(descripcion, accion, id_usuario, opciones) do
      nuevas_actividades = Map.put(estado.actividades, actividad.id, actividad)

      nuevo_estado = %{estado | actividades: nuevas_actividades}

      {:ok, actividad, nuevo_estado}
    end
  end

  @doc """
  Obtiene todas las actividades registradas.
  """
  def listar(%EstadoActividades{} = estado) do
    actividades =
      estado.actividades
      |> Map.values()
      |> Enum.sort_by(& &1.fecha, {:desc, DateTime})

    {:ok, actividades}
  end

  @doc """
  Busca las actividades realizadas por un usuario.
  """
  def listar_por_usuario(%EstadoActividades{} = estado, id_usuario) do
    actividades =
      estado.actividades
      |> Map.values()
      |> Enum.filter(&(&1.id_usuario == id_usuario))
      |> Enum.sort_by(& &1.fecha, {:desc, DateTime})

    {:ok, actividades}
  end

  @doc """
  Busca una actividad por su identificador.
  """
  def buscar(%EstadoActividades{} = estado, id_actividad) do
    case Map.fetch(estado.actividades, id_actividad) do
      {:ok, actividad} -> {:ok, actividad}
      :error -> {:error, "Actividad no encontrada"}
    end
  end

end
