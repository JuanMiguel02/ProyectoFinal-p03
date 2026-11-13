defmodule Emergencia.Consola.MenuTerritorio do
  @moduledoc """
  Gestiona las operaciones de consulta y registro del territorio.
  """

  alias Emergencia.Aplicacion.GestionTerritorio
  alias Emergencia.CentroAcopio
  alias Emergencia.Consola.FormatoConsola
  alias Emergencia.Consola.PermisosMenu
  alias Emergencia.PuntoAtencion
  alias Emergencia.Sector
  alias Emergencia.Zona
  alias Util

  @niveles %{
    "1" => :bajo,
    "2" => :medio,
    "3" => :alto,
    "4" => :critico
  }

  @tipos_punto %{
    "1" => :medico,
    "2" => :logistico,
    "3" => :distribucion
  }

  def iniciar(sesion) do
    Util.mostrar("\n========== GESTIÓN DEL TERRITORIO ==========", :mensaje)

    PermisosMenu.mostrar_opciones(sesion, [
      {"1", "Registrar zona", :crear_zona},
      {"2", "Registrar sector", :crear_sector},
      {"3", "Registrar centro de acopio", :crear_zona},
      {"4", "Registrar punto de atención", :crear_sector},
      {"5", "Listar zonas", :consultar_zonas},
      {"6", "Consultar estadísticas de zona", :consultar_zonas},
      {"7", "Listar centros de acopio", :consultar_zonas},
      {"8", "Volver", nil}
    ])

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        registrar_zona(sesion)

      "2" ->
        registrar_sector(sesion)

      "3" ->
        registrar_centro(sesion)

      "4" ->
        registrar_punto(sesion)

      "5" ->
        listar_zonas(sesion)

      "6" ->
        consultar_estadisticas(sesion)

      "7" ->
        listar_centros(sesion)

      "8" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida.", :error)
        iniciar(sesion)
    end
  end

  defp registrar_zona(sesion) do
    nombre = Util.ingresar("Nombre de la zona: ", :texto)
    nivel = seleccionar_nivel()
    personas = Util.ingresar("Personas estimadas: ", :entero)

    case nivel do
      {:ok, nivel} ->
        sesion
        |> GestionTerritorio.registrar_zona(nombre, nivel, personas)
        |> mostrar_resultado("Zona registrada:")

      {:error, motivo} ->
        Util.mostrar(motivo, :error)
    end

    iniciar(sesion)
  end

  defp registrar_sector(sesion) do
    zona = Util.ingresar("Código o ID de la zona: ", :texto)
    nombre = Util.ingresar("Nombre del sector: ", :texto)
    nivel = seleccionar_nivel()
    personas = Util.ingresar("Personas afectadas: ", :entero)

    case nivel do
      {:ok, nivel} ->
        sesion
        |> GestionTerritorio.registrar_sector(zona, nombre, nivel, personas)
        |> mostrar_resultado("Sector registrado:")

      {:error, motivo} ->
        Util.mostrar(motivo, :error)
    end

    iniciar(sesion)
  end

  defp registrar_centro(sesion) do
    nombre = Util.ingresar("Nombre del centro de acopio: ", :texto)
    direccion = Util.ingresar("Dirección: ", :texto)
    capacidad = Util.ingresar("Capacidad: ", :entero)
    zona = Util.ingresar("Código o ID de la zona: ", :texto)

    sesion
    |> GestionTerritorio.registrar_centro_acopio(nombre, direccion, capacidad, zona)
    |> mostrar_resultado("Centro de acopio registrado:")

    iniciar(sesion)
  end

  defp registrar_punto(sesion) do
    sector = Util.ingresar("Código o ID del sector: ", :texto)
    nombre = Util.ingresar("Nombre del punto de atención: ", :texto)

    Util.mostrar("Tipo de punto: 1. Médico  2. Logístico  3. Distribución", :mensaje)
    tipo = obtener_opcion(@tipos_punto, Util.ingresar("Seleccione el tipo: ", :texto))

    ubicacion = Util.ingresar("Ubicación: ", :texto)
    descripcion = Util.ingresar("Descripción (opcional): ", :texto)

    case tipo do
      {:ok, tipo} ->
        sesion
        |> GestionTerritorio.registrar_punto_atencion(
          sector,
          nombre,
          tipo,
          ubicacion,
          opcional(descripcion)
        )
        |> mostrar_resultado("Punto de atención registrado:")

      {:error, motivo} ->
        Util.mostrar(motivo, :error)
    end

    iniciar(sesion)
  end

  defp listar_zonas(sesion) do
    case GestionTerritorio.listar_zonas(sesion) do
      {:ok, []} ->
        Util.mostrar("No hay zonas registradas.", :mensaje)

      {:ok, zonas} ->
        Enum.each(zonas, fn zona ->
          Util.mostrar(
            "#{zona.codigo_zona} | #{zona.nombre} | Nivel: #{zona.nivel_afectacion} | " <>
              "Sectores: #{length(zona.sectores)}",
            :mensaje
          )
        end)

      {:error, motivo} ->
        Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp consultar_estadisticas(sesion) do
    zona = Util.ingresar("Código o ID de la zona: ", :texto)

    case GestionTerritorio.estadisticas_zona(sesion, zona) do
      {:ok, %{estadisticas: estadisticas, sectores: sectores}} ->
        Util.mostrar("\nZona: #{estadisticas.zona}", :mensaje)

        Util.mostrar(
          "Nivel general: #{FormatoConsola.estado(estadisticas.nivel_general)}",
          :mensaje
        )

        Util.mostrar("Personas estimadas: #{estadisticas.personas_estimadas_zona}", :mensaje)

        Util.mostrar(
          "Personas afectadas en sectores: #{estadisticas.personas_afectadas_sectores}",
          :mensaje
        )

        Util.mostrar("Sectores registrados: #{estadisticas.cantidad_sectores}", :mensaje)
        Util.mostrar("Puntos de atención: #{estadisticas.cantidad_puntos_atencion}", :mensaje)

        if sectores != [] do
          Util.mostrar("\n--- Sectores Registrados ---", :mensaje)
        end

        Enum.each(sectores, fn sector ->
          Util.mostrar(
            "#{sector.codigo_sector} - #{sector.nombre} | " <>
              "Nivel: #{FormatoConsola.estado(sector.nivel_afectacion)} | " <>
              "Personas afectadas: #{sector.personas_afectadas}",
            :mensaje
          )

          mostrar_puntos_atencion(sector.puntos_atencion)
        end)

      {:error, motivo} ->
        Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp mostrar_puntos_atencion([]), do: :ok

  defp mostrar_puntos_atencion(puntos) do
    Util.mostrar("  Puntos de Atención:", :mensaje)

    Enum.each(puntos, fn punto ->
      Util.mostrar(
        "    - #{punto.codigo_punto_atencion}: #{punto.nombre} (#{FormatoConsola.estado(punto.tipo)})",
        :mensaje
      )
    end)
  end

  defp listar_centros(sesion) do
    case GestionTerritorio.listar_centros_acopio(sesion) do
      {:ok, []} ->
        Util.mostrar("No hay centros de acopio registrados.", :mensaje)

      {:ok, centros} ->
        Enum.each(centros, fn centro ->
          Util.mostrar(
            "#{centro.codigo_centro_acopio} | #{centro.nombre} | #{centro.direccion} | " <>
              "Capacidad: #{centro.capacidad}",
            :mensaje
          )
        end)

      {:error, motivo} ->
        Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp seleccionar_nivel do
    Util.mostrar("Nivel: 1. Bajo  2. Medio  3. Alto  4. Crítico", :mensaje)
    obtener_opcion(@niveles, Util.ingresar("Seleccione el nivel: ", :texto))
  end

  defp obtener_opcion(opciones, opcion) do
    case Map.fetch(opciones, opcion) do
      {:ok, valor} -> {:ok, valor}
      :error -> {:error, "Opción no válida."}
    end
  end

  defp opcional(""), do: nil
  defp opcional(valor), do: valor

  defp mostrar_resultado({:ok, resultado}, mensaje) do
    Util.mostrar(mensaje, :mensaje)
    mostrar_detalle(resultado)
  end

  defp mostrar_resultado({:ok, resultado, {:advertencia, motivo}}, mensaje) do
    mostrar_resultado({:ok, resultado}, mensaje)
    Util.mostrar("Advertencia: #{inspect(motivo)}", :error)
  end

  defp mostrar_resultado({:error, motivo}, _mensaje) do
    Util.mostrar("No se pudo completar la operación: #{inspect(motivo)}", :error)
  end

  defp mostrar_detalle(%Zona{} = zona) do
    Util.mostrar("Código: #{zona.codigo_zona}", :mensaje)
    Util.mostrar("Nombre: #{zona.nombre}", :mensaje)
    Util.mostrar("Nivel de afectación: #{FormatoConsola.estado(zona.nivel_afectacion)}", :mensaje)
    Util.mostrar("Personas estimadas: #{zona.personas_estimadas}", :mensaje)
  end

  defp mostrar_detalle(%Sector{} = sector) do
    Util.mostrar("Código: #{sector.codigo_sector}", :mensaje)
    Util.mostrar("Nombre: #{sector.nombre}", :mensaje)

    Util.mostrar(
      "Nivel de afectación: #{FormatoConsola.estado(sector.nivel_afectacion)}",
      :mensaje
    )

    Util.mostrar("Personas afectadas: #{sector.personas_afectadas}", :mensaje)
  end

  defp mostrar_detalle(%CentroAcopio{} = centro) do
    Util.mostrar("Código: #{centro.codigo_centro_acopio}", :mensaje)
    Util.mostrar("Nombre: #{centro.nombre}", :mensaje)
    Util.mostrar("Dirección: #{centro.direccion}", :mensaje)
    Util.mostrar("Capacidad: #{centro.capacidad}", :mensaje)
  end

  defp mostrar_detalle(%PuntoAtencion{} = punto) do
    Util.mostrar("Código: #{punto.codigo_punto_atencion}", :mensaje)
    Util.mostrar("Nombre: #{punto.nombre}", :mensaje)
    Util.mostrar("Tipo: #{FormatoConsola.estado(punto.tipo)}", :mensaje)
    Util.mostrar("Ubicación: #{punto.ubicacion}", :mensaje)
    Util.mostrar("Descripción: #{punto.descripcion || "No especificada"}", :mensaje)
  end
end
