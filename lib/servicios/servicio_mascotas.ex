defmodule Emergencia.Servicios.ServicioMascotas do
  @moduledoc """
  Servicio puro para la gestión de mascotas perdidas y encontradas.
  """
  alias Emergencia.{ReporteMascota, CoincidenciaMascota}

  def registrar_reporte(
        estado,
        tipo,
        especie,
        color,
        tamano,
        id_zona,
        id_contacto,
        opciones \\ []
      ) do
    with {:ok, reporte} <-
           ReporteMascota.nueva(tipo, especie, color, tamano, id_zona, id_contacto, opciones) do
      nuevos_reportes = Map.put(estado.reportes_mascotas, reporte.id, reporte)
      estado_actualizado = %{estado | reportes_mascotas: nuevos_reportes}
      {:ok, reporte, estado_actualizado}
    end
  end

  def buscar_coincidencias(estado, id_reporte) do
    with {:ok, reporte_origen} <- obtener_reporte(estado.reportes_mascotas, id_reporte),
         :ok <- validar_reporte_activo(reporte_origen) do
      tipo_buscado = if reporte_origen.tipo == :perdida, do: :encontrada, else: :perdida

      coincidencias =
        estado.reportes_mascotas
        |> Map.values()
        |> Enum.filter(&(&1.tipo == tipo_buscado and &1.estado == :activa))
        |> Enum.map(fn r -> {r, calcular_similitud(reporte_origen, r)} end)
        # Umbral mínimo de similitud
        |> Enum.filter(fn {_r, puntaje} -> puntaje >= 40 end)
        # Las más parecidas primero
        |> Enum.sort_by(fn {_r, puntaje} -> puntaje end, :desc)
        |> Enum.map(fn {r, _puntaje} -> r end)

      {:ok, coincidencias}
    end
  end

  defp calcular_similitud(r1, r2) do
    puntaje = 0
    puntaje = if r1.especie == r2.especie, do: puntaje + 50, else: puntaje
    puntaje = if r1.color == r2.color, do: puntaje + 25, else: puntaje
    puntaje = if r1.tamano == r2.tamano, do: puntaje + 15, else: puntaje
    puntaje = if r1.id_zona == r2.id_zona, do: puntaje + 10, else: puntaje
    puntaje
  end

  def confirmar_coincidencia(estado, id_coincidencia, _id_usuario \\ "SISTEMA") do
    with {:ok, coincidencia} <- Map.fetch(estado.coincidencias_mascotas, id_coincidencia),
         :ok <- validar_coincidencia_pendiente(coincidencia),
         {:ok, rep_perdida} <-
           obtener_reporte(estado.reportes_mascotas, coincidencia.id_reporte_perdida),
         {:ok, rep_encontrada} <-
           obtener_reporte(estado.reportes_mascotas, coincidencia.id_reporte_encontrada),

         # Delegamos el cambio a la entidad para que valide si es legal pasar a :resuelta
         {:ok, rep_perdida_act} <-
           Emergencia.ReporteMascota.cambiar_estado(rep_perdida, :resuelta),
         {:ok, rep_encontrada_act} <-
           Emergencia.ReporteMascota.cambiar_estado(rep_encontrada, :resuelta) do
      coincidencia_act = %{coincidencia | estado: :confirmada}

      nuevos_reportes =
        estado.reportes_mascotas
        |> Map.put(rep_perdida.id, rep_perdida_act)
        |> Map.put(rep_encontrada.id, rep_encontrada_act)

      nuevas_coincidencias =
        Map.put(estado.coincidencias_mascotas, id_coincidencia, coincidencia_act)

      estado_actualizado = %{
        estado
        | reportes_mascotas: nuevos_reportes,
          coincidencias_mascotas: nuevas_coincidencias
      }

      {:ok, coincidencia_act, estado_actualizado}
    else
      :error -> {:error, "Coincidencia no encontrada"}
      # Si la máquina de estados devuelve un error (ej. la mascota ya estaba resuelta),
      # el bloque 'with' lo atrapará automáticamente aquí y lo devolverá intacto.
      error -> error
    end
  end

  def registrar_y_confirmar_coincidencia(
        estado,
        id_perdida,
        id_encontrada,
        id_usuario \\ "SISTEMA"
      ) do
    with {:ok, coincidencia, estado_actualizado} <-
           registrar_coincidencia(estado, id_perdida, id_encontrada, id_usuario),
         {:ok, coincidencia_confirmada, estado_final} <-
           confirmar_coincidencia(estado_actualizado, coincidencia.id, id_usuario) do
      {:ok, coincidencia_confirmada, estado_final}
    end
  end

  def registrar_coincidencia(estado, id_perdida, id_encontrada, _id_usuario \\ "SISTEMA") do
    with {:ok, rep_perdida} <- obtener_reporte(estado.reportes_mascotas, id_perdida),
         {:ok, rep_encontrada} <- obtener_reporte(estado.reportes_mascotas, id_encontrada),
         :ok <- validar_tipos_coincidencia(rep_perdida, rep_encontrada),
         :ok <- validar_reporte_activo(rep_perdida),
         :ok <- validar_reporte_activo(rep_encontrada),
         :ok <- validar_coincidencia_no_registrada(estado, id_perdida, id_encontrada),
         {:ok, coincidencia} <- CoincidenciaMascota.nueva(id_perdida, id_encontrada) do
      with {:ok, rep_perdida_act} <-
             ReporteMascota.cambiar_estado(rep_perdida, :posible_coincidencia),
           {:ok, rep_encontrada_act} <-
             ReporteMascota.cambiar_estado(rep_encontrada, :posible_coincidencia) do
        nuevos_reportes =
          estado.reportes_mascotas
          |> Map.put(id_perdida, rep_perdida_act)
          |> Map.put(id_encontrada, rep_encontrada_act)

        nuevas_coincidencias =
          Map.put(estado.coincidencias_mascotas, coincidencia.id, coincidencia)

        estado_actualizado = %{
          estado
          | reportes_mascotas: nuevos_reportes,
            coincidencias_mascotas: nuevas_coincidencias
        }

        {:ok, coincidencia, estado_actualizado}
      end
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

  @doc """
  Filtra reportes de mascotas usando múltiples criterios opcionales.
  Ej: buscar_reportes(estado, estado: :activa, especie: "perro")
  """
  def buscar_reportes(estado, criterios) do
    reportes =
      estado.reportes_mascotas
      |> Map.values()
      |> Enum.filter(fn r ->
        Enum.all?(criterios, fn
          {:especie, val} -> r.especie == normalizar_especie(val)
          {:id_zona, val} -> r.id_zona == val
          {:estado, val} -> r.estado == val
          _ -> false
        end)
      end)

    {:ok, reportes}
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

  defp validar_reporte_activo(%ReporteMascota{estado: :activa}), do: :ok

  defp validar_reporte_activo(%ReporteMascota{estado: estado}) do
    {:error, "Solo se pueden procesar reportes activos; el estado actual es #{estado}."}
  end

  defp validar_tipos_coincidencia(
         %ReporteMascota{tipo: :perdida},
         %ReporteMascota{tipo: :encontrada}
       ),
       do: :ok

  defp validar_tipos_coincidencia(_, _) do
    {:error, "La coincidencia requiere primero un reporte perdido y luego uno encontrado."}
  end

  defp validar_coincidencia_pendiente(%CoincidenciaMascota{estado: :pendiente}), do: :ok

  defp validar_coincidencia_pendiente(%CoincidenciaMascota{estado: estado}) do
    {:error, "La coincidencia ya fue procesada (estado: #{estado})."}
  end

  defp validar_coincidencia_no_registrada(estado, id_perdida, id_encontrada) do
    existe =
      Enum.any?(Map.values(estado.coincidencias_mascotas), fn coincidencia ->
        coincidencia.id_reporte_perdida == id_perdida and
          coincidencia.id_reporte_encontrada == id_encontrada
      end)

    if existe, do: {:error, "Ya existe una coincidencia para estos reportes."}, else: :ok
  end

  defp normalizar_especie(especie) when is_binary(especie),
    do: especie |> String.trim() |> String.downcase()

  defp normalizar_especie(especie) when is_atom(especie), do: Atom.to_string(especie)
  defp normalizar_especie(_), do: nil

  @doc """
  Función ejecutada en segundo plano por el Task para procesar emparejamientos.
  """
  def evaluar_coincidencias_background(reporte, estado) do
    case buscar_coincidencias(estado, reporte.id) do
      {:ok, coincidencias} when coincidencias != [] ->
        # Aquí en un caso real se registraría la coincidencia o se enviaría un mensaje al coordinador
        IO.puts(
          "\n[NOTIFICACIÓN BACKGROUND] ¡Se encontraron #{length(coincidencias)} posibles coincidencias para el reporte de mascota '#{reporte.id}'!"
        )

      _ ->
        IO.puts(
          "\n[NOTIFICACIÓN BACKGROUND] No se encontraron coincidencias inmediatas para la mascota."
        )
    end
  end
end
