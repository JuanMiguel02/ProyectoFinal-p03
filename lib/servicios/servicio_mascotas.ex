defmodule Emergencia.Servicios.ServicioMascotas do
  @moduledoc """
  Servicio puro para la gestión de mascotas perdidas y encontradas.
  """
  alias Emergencia.{ReporteMascota, CoincidenciaMascota}

  def registrar_reporte(estado, tipo, especie, color, tamano, id_zona, id_contacto, opciones \\ []) do
    with {:ok, reporte} <- ReporteMascota.nueva(tipo, especie, color, tamano, id_zona, id_contacto, opciones) do
      nuevos_reportes = Map.put(estado.reportes_mascotas, reporte.id, reporte)
      estado_actualizado = %{estado | reportes_mascotas: nuevos_reportes}
      {:ok, reporte, estado_actualizado}
    end
  end

  def buscar_coincidencias(estado, id_reporte) do
    with {:ok, reporte_origen} <- obtener_reporte(estado.reportes_mascotas, id_reporte) do
      tipo_buscado = if reporte_origen.tipo == :perdida, do: :encontrada, else: :perdida

      coincidencias =
        estado.reportes_mascotas
        |> Map.values()
        |> Enum.filter(fn r ->
          r.tipo == tipo_buscado and
          r.estado == :activa and
          r.especie == reporte_origen.especie and
          r.id_zona == reporte_origen.id_zona and
          (r.tamano == reporte_origen.tamano or r.color == reporte_origen.color)
        end)

      {:ok, coincidencias}
    end
  end

  def registrar_coincidencia(estado, id_perdida, id_encontrada, _id_usuario \\ "SISTEMA") do
    with {:ok, rep_perdida} <- obtener_reporte(estado.reportes_mascotas, id_perdida),
         {:ok, rep_encontrada} <- obtener_reporte(estado.reportes_mascotas, id_encontrada),
         {:ok, coincidencia} <- CoincidenciaMascota.nueva(id_perdida, id_encontrada) do

      rep_perdida_act = %{rep_perdida | estado: :posible_coincidencia}
      rep_encontrada_act = %{rep_encontrada | estado: :posible_coincidencia}

      nuevos_reportes =
        estado.reportes_mascotas
        |> Map.put(id_perdida, rep_perdida_act)
        |> Map.put(id_encontrada, rep_encontrada_act)

      nuevas_coincidencias = Map.put(estado.coincidencias_mascotas, coincidencia.id, coincidencia)

      estado_actualizado = %{
        estado |
        reportes_mascotas: nuevos_reportes,
        coincidencias_mascotas: nuevas_coincidencias
      }

      {:ok, coincidencia, estado_actualizado}
    end
  end

  def resolver_reporte(estado, id_reporte, _id_usuario \\ "SISTEMA") do
    with {:ok, reporte} <- obtener_reporte(estado.reportes_mascotas, id_reporte),
         :ok <- validar_no_resuelto(reporte) do

      reporte_actualizado = %{reporte | estado: :resuelta}
      nuevos_reportes = Map.put(estado.reportes_mascotas, id_reporte, reporte_actualizado)

      estado_actualizado = %{estado | reportes_mascotas: nuevos_reportes}
      {:ok, reporte_actualizado, estado_actualizado}
    end
  end

  defp obtener_reporte(reportes, id) do
    case Map.fetch(reportes, id) do
      {:ok, reporte} -> {:ok, reporte}
      :error -> {:error, "Reporte de mascota no encontrado"}
    end
  end

  defp validar_no_resuelto(%ReporteMascota{estado: :resuelta}) do
    {:error, "El reporte de mascota ya ha sido resuelto y no puede procesarse nuevamente"}
  end
  defp validar_no_resuelto(_), do: :ok
end
