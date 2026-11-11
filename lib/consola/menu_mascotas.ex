defmodule Emergencia.Consola.MenuMascotas do
  alias Emergencia.Aplicacion.GestionMascotas
  alias Emergencia.Aplicacion.GestionTerritorio
  alias Util

  @tipos %{"1" => :perdida, "2" => :encontrada}
  @tamanos %{"1" => :pequeno, "2" => :mediano, "3" => :grande}

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE MASCOTAS ---", :mensaje)
    Util.mostrar("1. Ver reportes", :mensaje)
    Util.mostrar("2. Buscar coincidencias sugeridas", :mensaje)
    Util.mostrar("3. Confirmar una coincidencia", :mensaje)
    Util.mostrar("4. Registrar reporte de mascota", :mensaje)
    Util.mostrar("5. Marcar reporte como resuelto", :mensaje)
    Util.mostrar("6. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        listar_reportes(sesion)
        iniciar(sesion)

      "2" ->
        buscar_coincidencias(sesion)
        iniciar(sesion)

      "3" ->
        confirmar_coincidencia(sesion)
        iniciar(sesion)

      "4" ->
        registrar_reporte(sesion)
        iniciar(sesion)

      "5" ->
        resolver_reporte(sesion)
        iniciar(sesion)

      "6" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end

  defp listar_reportes(sesion) do
    case GestionMascotas.listar_reportes(sesion) do
      {:ok, []} ->
        Util.mostrar("No hay reportes de mascotas.", :mensaje)

      {:ok, reportes} ->
        Enum.each(reportes, fn reporte ->
          Util.mostrar(
            "[#{reporte.id}] #{reporte.tipo} | #{reporte.especie} | " <>
              "Color: #{reporte.color} | Estado: #{reporte.estado}",
            :mensaje
          )
        end)

      {:error, motivo} ->
        Util.mostrar("No se pudieron consultar reportes: #{inspect(motivo)}", :error)
    end
  end

  defp buscar_coincidencias(sesion) do
    with {:ok, reportes} <- GestionMascotas.listar_reportes(sesion),
         {:ok, zonas} <- GestionTerritorio.listar_zonas(sesion) do
      codigos_zona = Map.new(zonas, &{&1.id, &1.codigo_zona})

      perdidas = Enum.filter(reportes, &(&1.tipo == :perdida and &1.estado == :activa))

      if perdidas == [] do
        Util.mostrar("No hay reportes de mascotas perdidas activos.", :mensaje)
      else
        Enum.each(perdidas, fn perdida ->
          case GestionMascotas.buscar_coincidencias(sesion, perdida.id) do
            {:ok, candidatas} ->
              Util.mostrar(
                "\nPerdida: #{perdida.especie}, #{perdida.color}, #{perdida.tamano} " <>
                  "| Zona: #{Map.get(codigos_zona, perdida.id_zona, "desconocida")}",
                :mensaje
              )

              case candidatas do
                [] ->
                  Util.mostrar("  Sin coincidencias sugeridas.", :mensaje)

                candidatas ->
                  Enum.each(candidatas, fn candidata ->
                    Util.mostrar(
                      "  Encontrada [#{candidata.id}]: #{candidata.especie}, " <>
                        "#{candidata.color}, #{candidata.tamano}",
                      :mensaje
                    )
                  end)
              end

            {:error, motivo} ->
              Util.mostrar("No se pudieron buscar coincidencias: #{inspect(motivo)}", :error)
          end
        end)
      end
    else
      {:error, motivo} ->
        Util.mostrar("No se pudieron consultar reportes: #{inspect(motivo)}", :error)
    end
  end

  defp confirmar_coincidencia(sesion) do
    with {:ok, coincidencias} <- GestionMascotas.listar_coincidencias(sesion),
         true <- coincidencias != [] do
      Enum.each(coincidencias, fn coincidencia ->
        Util.mostrar(
          "[#{coincidencia.id}] Pérdida: #{coincidencia.id_reporte_perdida} | " <>
            "Encontrada: #{coincidencia.id_reporte_encontrada} | Estado: #{coincidencia.estado}",
          :mensaje
        )
      end)

      identificador = Util.ingresar("ID de la coincidencia a confirmar: ", :texto)

      case GestionMascotas.confirmar_coincidencia(sesion, identificador) do
        {:ok, _coincidencia} ->
          Util.mostrar("Coincidencia confirmada; los reportes fueron cerrados.", :mensaje)

        {:ok, _coincidencia, {:advertencia, motivo}} ->
          Util.mostrar("Coincidencia confirmada.", :mensaje)
          Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

        {:error, motivo} ->
          Util.mostrar("No se pudo confirmar la coincidencia: #{inspect(motivo)}", :error)
      end
    else
      false ->
        Util.mostrar("No hay coincidencias registradas.", :mensaje)

      {:error, motivo} ->
        Util.mostrar("No se pudieron consultar coincidencias: #{inspect(motivo)}", :error)
    end
  end

  defp registrar_reporte(sesion) do
    Util.mostrar("Tipo: 1. Perdida  2. Encontrada", :mensaje)
    tipo = seleccionar(@tipos, "Seleccione el tipo: ")
    especie = Util.ingresar("Especie: ", :texto)
    nombre = Util.ingresar("Nombre (opcional): ", :texto)
    color = Util.ingresar("Color: ", :texto)
    Util.mostrar("Tamaño: 1. Pequeño  2. Mediano  3. Grande", :mensaje)
    tamano = seleccionar(@tamanos, "Seleccione el tamaño: ")
    zona = Util.ingresar("Código de zona: ", :texto)
    caracteristicas = Util.ingresar("Características adicionales (opcional): ", :texto)

    with {:ok, tipo} <- tipo,
         {:ok, tamano} <- tamano do
      opciones =
        []
        |> agregar_opcion(:nombre, nombre)
        |> agregar_opcion(:caracteristicas, caracteristicas)

      case GestionMascotas.registrar_reporte(
             sesion,
             tipo,
             especie,
             color,
             tamano,
             zona,
             nil,
             opciones
           ) do
        {:ok, reporte} ->
          Util.mostrar("Reporte registrado [ID: #{reporte.id}].", :mensaje)

        {:ok, reporte, {:advertencia, motivo}} ->
          Util.mostrar("Reporte registrado [ID: #{reporte.id}].", :mensaje)
          Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

        {:error, motivo} ->
          Util.mostrar("No se pudo registrar el reporte: #{inspect(motivo)}", :error)
      end
    else
      {:error, motivo} -> Util.mostrar(motivo, :error)
    end
  end

  defp resolver_reporte(sesion) do
    identificador = Util.ingresar("ID del reporte a resolver: ", :texto)

    with {:ok, reportes} <- GestionMascotas.listar_reportes(sesion),
         {:ok, reporte} <- buscar_reporte(reportes, identificador) do
      case GestionMascotas.resolver_reporte(sesion, reporte.id) do
        {:ok, reporte} ->
          Util.mostrar("Reporte #{reporte.id} marcado como resuelto.", :mensaje)

        {:ok, reporte, {:advertencia, motivo}} ->
          Util.mostrar("Reporte #{reporte.id} marcado como resuelto.", :mensaje)
          Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

        {:error, motivo} ->
          Util.mostrar("No se pudo resolver el reporte: #{inspect(motivo)}", :error)
      end
    else
      {:error, motivo} ->
        Util.mostrar("No se pudo resolver el reporte: #{inspect(motivo)}", :error)
    end
  end

  defp buscar_reporte(reportes, identificador) do
    codigo = String.upcase(identificador)

    case Enum.filter(reportes, fn reporte ->
           reporte.id == identificador or
             (Map.get(reporte, :codigo_reporte) != nil and
                String.upcase(reporte.codigo_reporte) == codigo)
         end) do
      [reporte] -> {:ok, reporte}
      [] -> {:error, "No se encontró un reporte con ese ID o código."}
      _ -> {:error, "Hay varios reportes coincidentes; utilice un identificador más específico."}
    end
  end

  defp seleccionar(opciones, mensaje) do
    case Map.fetch(opciones, Util.ingresar(mensaje, :texto)) do
      {:ok, valor} -> {:ok, valor}
      :error -> {:error, "Opción no válida."}
    end
  end

  defp agregar_opcion(opciones, _campo, ""), do: opciones
  defp agregar_opcion(opciones, campo, valor), do: Keyword.put(opciones, campo, valor)
end
