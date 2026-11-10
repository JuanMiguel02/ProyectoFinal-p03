defmodule Emergencia.Consola.CLI do
  @moduledoc """
  Interfaz de línea de comandos (capa de PRESENTACIÓN).

  Arquitectura por capas:

      Datos <- Servicio <- Servidor <- Gestión (Aplicación) <- CLI

  Este módulo únicamente:

    * lee y parsea lo que escribe el usuario,
    * convierte los textos a tipos de Elixir (enteros, átomos),
    * invoca funciones de `Emergencia.Aplicacion.*` pasando la sesión,
    * da formato a las respuestas.

  No conoce a los servidores (`*Servidor`), ni a los servicios, ni a la
  persistencia. La autorización, la resolución de códigos (`ZON-0001`,
  `NEC-0001`, documentos, UUIDs) y la auditoría viven en la capa de Aplicación.
  """

  alias Emergencia.Aplicacion.{
    Autenticacion,
    GestionUsuarios,
    GestionTerritorio,
    GestionRecursos,
    GestionPersonas,
    GestionAlbergues,
    GestionMensajes,
    GestionMascotas,
    GestionResumen
  }

  @tipos_usuario %{
    "ciudadano" => :ciudadano,
    "voluntario" => :voluntario,
    "coordinador" => :coordinador,
    "administrador" => :administrador
  }

  @tipos_reporte %{
    "lost" => :perdida,
    "perdida" => :perdida,
    "found" => :encontrada,
    "encontrada" => :encontrada
  }

  @filtros_necesidades %{
    "zona" => :zona,
    "tipo" => :tipo,
    "prioridad" => :prioridad,
    "estado" => :estado
  }

  # ============================================================================
  # BUCLE PRINCIPAL
  # ============================================================================

  def iniciar do
    IO.puts("\n========================================================")
    IO.puts("    SISTEMA DISTRIBUIDO DE COORDINACIÓN DE EMERGENCIAS")
    IO.puts("========================================================")
    IO.puts("Escribe 'help' para ver los comandos disponibles o 'exit' para salir.\n")
    bucle_principal(nil)
  end

  defp bucle_principal(sesion) do
    prompt = if sesion, do: "[#{sesion.nombre_usuario} (#{sesion.tipo_usuario})]> ", else: "> "

    case IO.gets(prompt) do
      linea when is_binary(linea) ->
        argumentos = linea |> String.trim() |> parsear_argumentos()
        bucle_principal(evaluar_comando(argumentos, sesion))

      _fin_de_entrada ->
        evaluar_comando(["exit"], sesion)
    end
  end

  # Permite agrupar texto entre comillas como un solo argumento
  defp parsear_argumentos(cadena) do
    ~r/[^\s"']+|"([^"]*)"|'([^']*)'/
    |> Regex.scan(cadena)
    |> Enum.map(fn
      [completo] -> completo
      [_, grupo1] when grupo1 != "" -> grupo1
      [_, _, grupo2] -> grupo2
      _ -> ""
    end)
    |> Enum.reject(&(&1 == ""))
  end

  # ============================================================================
  # 1. COMANDOS GENERALES
  # ============================================================================

  defp evaluar_comando(["exit"], sesion) do
    if sesion, do: Autenticacion.cerrar_sesion(sesion)
    IO.puts("Saliendo del sistema de emergencias. ¡Hasta pronto!")
    System.halt(0)
  end

  defp evaluar_comando(["help"], sesion) do
    IO.puts("""
    ================== COMANDOS DISPONIBLES ==================
        Autenticación:
          connect <usuario> <contraseña> <tipo> <zona>
          disconnect

        Territorio:
          register_zone <nombre> <nivel> <personas>
          register_sector <zona> <nombre> <nivel> <personas>
          register_center <nombre> <direccion> <capacidad> <zona>
          register_point <sector> <nombre> <tipo> <ubicacion> [descripcion]
          list_zones
          zone_stats <zona>

        Recursos y Necesidades:
          register_need <tipo> <cantidad> <prioridad> <zona> <descripcion>
          register_resource <nombre> <cantidad> <unidad> <ubicacion>
          assign_resource <necesidad> <recurso> <cantidad>
          transfer_resource <recurso> <origen> <destino> <cantidad>
          list_needs [zona=..] [tipo=..] [prioridad=..] [estado=..]
          pending_needs
          list_ordered_needs
          list_resources [ubicacion]
          list_all_resources
          check_stock <recurso>
          critical_resources

        Población y Albergues:
          report_person <documento> <nombre> <zona> <estado>
          find_person <documento>
          register_shelter <codigo> <nombre> <zona> <capacidad>
          check_shelter <albergue>
          shelter_report
          register_entry <albergue> <documento>
          register_exit <albergue> <documento>

        Comunicaciones y Mascotas:
          send_family_message <documento_o_familia> <contenido>
          list_family_messages <documento>
          confirm_delivery <id_registro_destinatario>
          report_pet <lost|found> <especie> <nombre> <color> <tamano> <zona> <contacto>
          match_pets

        General:
          summary
          exit
      ==========================================================
    """)

    sesion
  end

  defp evaluar_comando([], sesion), do: sesion

  # ============================================================================
  # 2. AUTENTICACIÓN
  # ============================================================================

  defp evaluar_comando(["connect", usuario, contrasena, tipo_texto, _zona], sesion) do
    cond do
      sesion != nil ->
        IO.puts("Ya hay una sesión activa. Usa 'disconnect' primero.")
        sesion

      is_nil(Map.get(@tipos_usuario, String.downcase(tipo_texto))) ->
        IO.puts(
          "Error: Tipo de usuario no válido (ciudadano, voluntario, coordinador, administrador)."
        )

        nil

      true ->
        tipo = Map.fetch!(@tipos_usuario, String.downcase(tipo_texto))
        conectar(usuario, contrasena, tipo)
    end
  end

  defp evaluar_comando(["disconnect"], nil) do
    IO.puts("No hay ninguna sesión activa.")
    nil
  end

  defp evaluar_comando(["disconnect"], sesion) do
    case Autenticacion.cerrar_sesion(sesion) do
      {:error, motivo} -> IO.puts("Error al cerrar sesión: #{formatear_error(motivo)}")
      _ok -> IO.puts("Sesión cerrada correctamente.")
    end

    nil
  end

  # ============================================================================
  # 3. TERRITORIO
  # ============================================================================

  defp evaluar_comando(["register_zone", nombre, nivel, personas], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, nivel} <- a_atomo(nivel),
             {:ok, personas} <- a_entero(personas) do
          GestionTerritorio.registrar_zona(sesion, nombre, nivel, personas)
        end
      end,
      fn z -> "Zona registrada [Código: #{z.codigo_zona}, ID: #{z.id}]" end
    )
  end

  defp evaluar_comando(["register_sector", zona, nombre, nivel, personas], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, nivel} <- a_atomo(nivel),
             {:ok, personas} <- a_entero(personas) do
          GestionTerritorio.registrar_sector(sesion, zona, nombre, nivel, personas)
        end
      end,
      fn s -> "Sector registrado [Código: #{s.codigo_sector}, ID: #{s.id}]" end
    )
  end

  defp evaluar_comando(["register_center", nombre, direccion, capacidad, zona], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, capacidad} <- a_entero(capacidad) do
          GestionTerritorio.registrar_centro_acopio(sesion, nombre, direccion, capacidad, zona)
        end
      end,
      fn c ->
        "Centro de acopio registrado [Código: #{c.codigo_centro_acopio}, ID: #{c.id}]"
      end
    )
  end

  defp evaluar_comando(
         ["register_point", sector, nombre, tipo_texto, ubicacion],
         sesion
       ) do
    registrar_punto_atencion(sector, nombre, tipo_texto, ubicacion, nil, sesion)
  end

  defp evaluar_comando(
         ["register_point", sector, nombre, tipo_texto, ubicacion, descripcion],
         sesion
       ) do
    registrar_punto_atencion(sector, nombre, tipo_texto, ubicacion, descripcion, sesion)
  end

  defp evaluar_comando(["list_zones"], sesion) do
    ejecutar(
      sesion,
      fn -> GestionTerritorio.listar_zonas(sesion) end,
      fn
        [] ->
          "No hay zonas registradas."

        zonas ->
          lineas =
            Enum.map_join(zonas, "\n", fn z ->
              "ID: #{z.id} | Código: #{z.codigo_zona} | Nombre: #{z.nombre}"
            end)

          "\n--- Zonas ---\n" <> lineas
      end
    )
  end

  defp evaluar_comando(["zone_stats", zona], sesion) do
    ejecutar(
      sesion,
      fn -> GestionTerritorio.estadisticas_zona(sesion, zona) end,
      fn %{estadisticas: s, sectores: sectores} ->
        cabecera = """

        --- Estadísticas de la Zona ---
        Nombre: #{s.zona}
        Nivel General: #{s.nivel_general}
        Personas Estimadas: #{s.personas_estimadas_zona}
        Personas Afectadas en Sectores: #{s.personas_afectadas_sectores}
        Total Sectores: #{s.cantidad_sectores}
        Puntos de Atención: #{s.cantidad_puntos_atencion}\
        """

        detalle =
          case sectores do
            [] ->
              "\nNo hay sectores registrados en esta zona."

            _ ->
              "\n\n--- Sectores Registrados ---\n" <>
                Enum.map_join(sectores, "\n", fn sec ->
                  "Código: #{sec.codigo_sector} | Nombre: #{sec.nombre} | Afectados: #{sec.personas_afectadas}"
                end)
          end

        cabecera <> detalle
      end
    )
  end

  # ============================================================================
  # 4. RECURSOS Y NECESIDADES
  # ============================================================================

  defp evaluar_comando(["register_need", tipo, cantidad, prioridad, zona, descripcion], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, tipo} <- a_atomo(tipo),
             {:ok, cantidad} <- a_entero(cantidad),
             {:ok, prioridad} <- a_atomo(prioridad) do
          GestionRecursos.registrar_necesidad(sesion, tipo, cantidad, zona, prioridad,
            descripcion: descripcion
          )
        end
      end,
      fn n -> "Necesidad registrada [Código: #{n.codigo_necesidad}, ID: #{n.id}]" end
    )
  end

  defp evaluar_comando(["register_resource", nombre, cantidad, unidad, ubicacion], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, cantidad} <- a_entero(cantidad) do
          GestionRecursos.registrar_recurso(
            sesion,
            nombre,
            cantidad,
            unidad,
            ubicacion
          )
        end
      end,
      fn r ->
        "Recurso registrado: #{r.nombre} | Código: #{r.codigo} | Stock inicial: #{cantidad} #{r.unidad_medida} en #{ubicacion}"
      end
    )
  end

  defp evaluar_comando(["assign_resource", necesidad, recurso, cantidad], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, cantidad} <- a_entero(cantidad) do
          GestionRecursos.asignar_recurso(sesion, necesidad, recurso, cantidad)
        end
      end,
      fn asignaciones ->
        ids = Enum.map_join(asignaciones, ", ", & &1.id)
        "Recurso asignado [IDs: #{ids}]"
      end
    )
  end

  defp evaluar_comando(["transfer_resource", recurso, origen, destino, cantidad], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, cantidad} <- a_entero(cantidad) do
          GestionRecursos.transferir_recurso(sesion, recurso, origen, destino, cantidad)
        end
      end,
      fn mov ->
        "¡Transferencia exitosa! Se movieron las unidades al destino [Movimiento ID: #{mov.id}]"
      end
    )
  end

  defp evaluar_comando(["list_resources"], sesion), do: listar_recursos(nil, sesion)

  defp evaluar_comando(["list_resources", ubicacion], sesion),
    do: listar_recursos(ubicacion, sesion)

  defp evaluar_comando(["list_all_resources"], sesion) do
    ejecutar(
      sesion,
      fn -> GestionRecursos.listar_todos_recursos(sesion) end,
      fn
        [] ->
          "Sin recursos registrados."

        recursos ->
          "\n--- Catálogo de Recursos ---\n" <>
            Enum.map_join(recursos, "\n", fn recurso ->
              ubicacion = recurso.ubicacion || "Sin ubicación"

              "Código: #{recurso.codigo} | Nombre: #{recurso.nombre} | Categoría: #{recurso.categoria} | Ubicación: #{ubicacion} | Disponible: #{recurso.cantidad} #{recurso.unidad_medida}"
            end)
      end
    )
  end

  defp evaluar_comando(["list_needs" | filtros], sesion), do: listar_necesidades(filtros, sesion)

  defp evaluar_comando(["pending_needs"], sesion),
    do: listar_necesidades(["estado=pendiente"], sesion)

  defp evaluar_comando(["list_ordered_needs"], sesion) do
    ejecutar(
      sesion,
      fn -> GestionRecursos.listar_necesidades_ordenadas(sesion) end,
      fn
        [] ->
          "Sin necesidades."

        necesidades ->
          "\n--- Necesidades Ordenadas por Prioridad ---\n" <>
            Enum.map_join(necesidades, "\n", fn n ->
              "[#{n.prioridad}] Código: #{n.codigo_necesidad} | Tipo: #{n.tipo} | Pendiente: #{n.cantidad_pendiente}"
            end)
      end
    )
  end

  defp evaluar_comando(["check_stock", recurso], sesion) do
    ejecutar(
      sesion,
      fn -> GestionRecursos.calcular_stock_global(sesion, recurso) end,
      fn total -> "\nStock global acumulado para el recurso [#{recurso}]: #{total} unidades." end
    )
  end

  defp evaluar_comando(["critical_resources"], sesion) do
    ejecutar(
      sesion,
      fn -> GestionResumen.recursos_criticos(sesion) end,
      fn
        [] ->
          "\n--- Stock Crítico ---\nNo hay existencias en nivel crítico."

        existencias ->
          "\n--- Stock Crítico ---\n" <>
            Enum.map_join(existencias, "\n", fn recurso ->
              "Código: #{recurso.codigo} | Ubicación: #{recurso.ubicacion} | Disp: #{recurso.cantidad} #{recurso.unidad_medida}"
            end)
      end
    )
  end

  # ============================================================================
  # 5. POBLACIÓN Y ALBERGUES
  # ============================================================================

  defp evaluar_comando(["report_person", documento, nombre, zona, estado], sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, estado} <- a_atomo(estado) do
          GestionPersonas.registrar_persona(sesion, nombre, documento, zona, estado)
        end
      end,
      fn p -> "Persona registrada [Código: #{p.codigo_persona}]" end
    )
  end

  defp evaluar_comando(["find_person", documento], sesion) do
    ejecutar(
      sesion,
      fn -> GestionPersonas.consultar_historial(sesion, documento) end,
      fn info ->
        base = "\n--- Persona ---\nNombre: #{info.nombre} | Estado: #{info.estado}"

        case Map.get(info, :historial_estados, []) do
          [] ->
            base

          historial ->
            base <>
              "\nHistorial de estados:\n" <>
              Enum.map_join(historial, "\n", fn
                {estado, fecha} -> "  - #{estado} (#{fecha})"
                otro -> "  - #{inspect(otro)}"
              end)
        end
      end
    )
  end

  defp evaluar_comando(["register_shelter", _codigo, nombre, zona, capacidad], sesion) do
    # El código del albergue lo genera el sistema; el argumento se conserva
    # solo por compatibilidad con el comando de referencia.
    ejecutar(
      sesion,
      fn ->
        with {:ok, capacidad} <- a_entero(capacidad) do
          GestionAlbergues.registrar_albergue(sesion, nombre, zona, capacidad)
        end
      end,
      fn a -> "Albergue registrado [Código: #{a.codigo}, ID: #{a.id}]" end
    )
  end

  defp evaluar_comando(["check_shelter", albergue], sesion) do
    ejecutar(
      sesion,
      fn -> GestionAlbergues.consultar_ocupacion(sesion, albergue) end,
      fn info ->
        "\n--- Albergue ---\nCapacidad: #{info.capacidad_maxima} | Ocupación: #{info.ocupacion_actual} | Disponibles: #{info.cupos_disponibles}"
      end
    )
  end

  defp evaluar_comando(["shelter_report"], sesion) do
    ejecutar(
      sesion,
      fn -> GestionAlbergues.reporte_ocupacion(sesion) end,
      fn
        [] ->
          "No hay albergues registrados."

        reporte ->
          "\n--- Albergues por nivel de ocupación ---\n" <>
            Enum.map_join(reporte, "\n", fn a ->
              "#{a.codigo} | #{a.nombre} | #{a.ocupacion_actual}/#{a.capacidad_maxima} (#{a.porcentaje_ocupacion}%)"
            end)
      end
    )
  end

  defp evaluar_comando(["register_entry", albergue, documento], sesion) do
    ejecutar(
      sesion,
      fn -> GestionAlbergues.ingresar_persona(sesion, documento, albergue) end,
      fn _registro -> "Ingreso registrado correctamente." end
    )
  end

  defp evaluar_comando(["register_exit", _albergue, documento], sesion) do
    ejecutar(
      sesion,
      fn -> GestionAlbergues.registrar_salida(sesion, documento) end,
      fn _registro -> "Salida registrada correctamente." end
    )
  end

  # ============================================================================
  # 6. COMUNICACIONES Y MASCOTAS
  # ============================================================================

  defp evaluar_comando(["send_family_message", destinatario, contenido], sesion) do
    ejecutar(
      sesion,
      fn -> GestionMensajes.enviar_mensaje(sesion, destinatario, contenido) end,
      fn _resultado -> "¡Mensaje enviado y enrutado con éxito!" end
    )
  end

  defp evaluar_comando(["list_family_messages", documento], sesion) do
    ejecutar(
      sesion,
      fn -> GestionMensajes.obtener_mensajes_persona(sesion, documento) end,
      fn
        [] ->
          "No hay mensajes."

        mensajes ->
          "\n--- Mensajes ---\n" <>
            Enum.map_join(mensajes, "\n", fn m ->
              "[#{m.id_registro}] Estado: #{m.estado_entrega} | Texto: #{m.mensaje.contenido}"
            end)
      end
    )
  end

  defp evaluar_comando(["confirm_delivery", id_registro], sesion) do
    ejecutar(
      sesion,
      fn -> GestionMensajes.confirmar_entrega(sesion, id_registro) end,
      fn _resultado -> "¡Entrega confirmada exitosamente!" end
    )
  end

  defp evaluar_comando(
         ["report_pet", tipo, especie, nombre, color, tamano, zona, contacto],
         sesion
       ) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, tipo} <- a_tipo_reporte(tipo),
             {:ok, tamano} <- a_atomo(tamano) do
          GestionMascotas.registrar_reporte(sesion, tipo, especie, color, tamano, zona, contacto,
            nombre: nombre
          )
        end
      end,
      fn r -> "Reporte de mascota registrado [ID: #{r.id}]" end
    )
  end

  defp evaluar_comando(["match_pets"], sesion) do
    ejecutar(
      sesion,
      fn -> buscar_coincidencias_mascotas(sesion) end,
      fn
        [] ->
          "No hay reportes de mascotas perdidas activas."

        resultados ->
          "\n--- Posibles coincidencias ---\n" <>
            Enum.map_join(resultados, "\n", fn {perdida, candidatas} ->
              encabezado = "Perdida [#{perdida.id}] #{perdida.especie} #{perdida.color}"

              case candidatas do
                [] ->
                  encabezado <> " -> sin coincidencias"

                _ ->
                  encabezado <>
                    " ->\n" <>
                    Enum.map_join(candidatas, "\n", fn c ->
                      "    Encontrada [#{c.id}] #{c.especie} #{c.color} (#{c.tamano})"
                    end)
              end
            end)
      end
    )
  end

  # ============================================================================
  # 7. RESUMEN GENERAL
  # ============================================================================

  defp evaluar_comando(["summary"], sesion) do
    ejecutar(
      sesion,
      fn -> GestionResumen.resumen_global(sesion) end,
      fn r ->
        """

        ================ RESUMEN GLOBAL DEL SISTEMA ================
         - Zonas registradas: #{r.zonas}
         - Necesidades totales: #{r.necesidades_totales} (pendientes: #{r.necesidades_pendientes})
         - Albergues operativos: #{r.albergues}
         - Personas registradas: #{r.personas_registradas} (localizadas: #{r.personas_localizadas})
         - Mensajes: #{r.mensajes}
         - Reportes de mascotas: #{r.reportes_mascotas} (activos: #{r.reportes_mascotas_activos})
         - Unidades de recursos disponibles: #{r.unidades_disponibles}
        ============================================================\
        """
      end
    )
  end

  defp evaluar_comando([comando | _], sesion) do
    IO.puts("Comando desconocido o con argumentos incorrectos: '#{comando}'. Escribe 'help'.")
    sesion
  end

  defp listar_recursos(ubicacion, sesion) do
    ejecutar(
      sesion,
      fn -> GestionRecursos.listar_recursos(sesion, ubicacion) end,
      fn
        [] ->
          "Sin recursos."

        recursos ->
          "\n--- Recursos ---\n" <>
            Enum.map_join(recursos, "\n", fn recurso ->
              "Código: #{recurso.codigo} | Nombre: #{recurso.nombre} | Cat: #{recurso.categoria} | Ubicación: #{recurso.ubicacion} | Disponible: #{recurso.cantidad} #{recurso.unidad_medida}"
            end)
      end
    )
  end

  # ============================================================================
  # AUXILIARES DE FLUJO
  # ============================================================================

  defp registrar_punto_atencion(sector, nombre, tipo_texto, ubicacion, descripcion, sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, tipo} <- a_atomo(tipo_texto) do
          GestionTerritorio.registrar_punto_atencion(
            sesion,
            sector,
            nombre,
            tipo,
            ubicacion,
            descripcion
          )
        end
      end,
      fn punto ->
        "Punto de atención registrado [Código: #{punto.codigo_punto_atencion}, ID: #{punto.id}]"
      end
    )
  end

  # Registra (si hace falta) e inicia sesión usando solo la capa de Aplicación.
  defp conectar(usuario, contrasena, tipo) do
    case GestionUsuarios.registrar_usuario(usuario, contrasena, usuario, tipo) do
      {:ok, _usuario} -> IO.puts("Cuenta creada exitosamente.")
      {:ok, _usuario, _advertencia} -> IO.puts("Cuenta creada exitosamente.")
      # Usuario ya existente o rol que no permite autoregistro: se intenta el login.
      {:error, _motivo} -> :ok
    end

    case Autenticacion.iniciar_sesion(usuario, contrasena) do
      {:ok, sesion} ->
        IO.puts("Conectado exitosamente como #{sesion.nombre_completo}.")
        sesion

      {:ok, sesion, _advertencia} ->
        IO.puts("Conectado exitosamente como #{sesion.nombre_completo}.")
        sesion

      {:error, motivo} ->
        IO.puts("Error de autenticación: #{formatear_error(motivo)}")
        nil
    end
  end

  defp listar_necesidades(filtros, sesion) do
    ejecutar(
      sesion,
      fn ->
        with {:ok, criterios} <- parsear_filtros(filtros) do
          GestionRecursos.listar_necesidades(sesion, criterios)
        end
      end,
      fn
        [] ->
          "Sin necesidades."

        necesidades ->
          "\n--- Necesidades ---\n" <>
            Enum.map_join(necesidades, "\n", fn n ->
              "Código: #{n.codigo_necesidad} | Tipo: #{n.tipo} | Prioridad: #{n.prioridad} | Cant: #{n.cantidad_requerida} | Estado: #{n.estado}"
            end)
      end
    )
  end

  # Para cada reporte de mascota perdida y activa, pide a la capa de
  # Aplicación los reportes de mascotas encontradas que se le parecen.
  defp buscar_coincidencias_mascotas(sesion) do
    with {:ok, reportes} <- GestionMascotas.listar_reportes(sesion) do
      reportes
      |> Enum.filter(&(&1.tipo == :perdida and &1.estado == :activa))
      |> Enum.reduce_while({:ok, []}, fn perdida, {:ok, acumulado} ->
        case GestionMascotas.buscar_coincidencias(sesion, perdida.id) do
          {:ok, candidatas} -> {:cont, {:ok, [{perdida, candidatas} | acumulado]}}
          {:error, _} = error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, resultados} -> {:ok, Enum.reverse(resultados)}
        error -> error
      end
    end
  end

  # Ejecuta una acción que requiere sesión y muestra el resultado.
  # `accion` devuelve el resultado de la capa de Aplicación;
  # `formato` convierte el valor de éxito en el texto a mostrar.
  defp ejecutar(nil, _accion, _formato) do
    IO.puts("Inicia sesión primero.")
    nil
  end

  defp ejecutar(sesion, accion, formato) do
    accion.() |> responder(formato)
    sesion
  end

  defp responder({:ok, valor}, formato), do: IO.puts(formato.(valor))

  defp responder({:ok, valor, {:advertencia, advertencia}}, formato) do
    IO.puts(formato.(valor))
    IO.puts("Advertencia: #{formatear_error(advertencia)}")
  end

  defp responder({:error, motivo}, _formato), do: IO.puts("Error: #{formatear_error(motivo)}")
  defp responder(otro, _formato), do: IO.puts("Respuesta inesperada: #{inspect(otro)}")

  defp formatear_error(motivo) when is_binary(motivo), do: motivo
  defp formatear_error(motivo), do: inspect(motivo)

  # ============================================================================
  # CONVERSIÓN Y VALIDACIÓN DE ENTRADA (responsabilidad de la presentación)
  # ============================================================================

  defp a_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, "'#{texto}' no es un número entero válido"}
    end
  end

  # Convierte texto a átomo solo si tiene forma de identificador simple,
  # evitando crear átomos arbitrarios a partir de la entrada del usuario.
  defp a_atomo(texto) do
    normalizado =
      texto
      |> String.trim()
      |> String.downcase()
      |> String.replace("ñ", "n")
      |> String.replace(~r/[\s-]+/, "_")

    if Regex.match?(~r/^[a-z_]{1,40}$/, normalizado) do
      {:ok, String.to_atom(normalizado)}
    else
      {:error, "Valor no válido: '#{texto}'"}
    end
  end

  defp a_tipo_reporte(texto) do
    case Map.fetch(@tipos_reporte, String.downcase(texto)) do
      {:ok, tipo} -> {:ok, tipo}
      :error -> {:error, "Tipo de reporte no válido: '#{texto}' (usa lost o found)"}
    end
  end

  defp parsear_filtros(filtros) do
    Enum.reduce_while(filtros, {:ok, []}, fn filtro, {:ok, acumulado} ->
      with [clave, valor] <- String.split(filtro, "=", parts: 2),
           {:ok, clave_atomo} <- Map.fetch(@filtros_necesidades, clave) do
        {:cont, {:ok, [{clave_atomo, valor} | acumulado]}}
      else
        _ ->
          {:halt,
           {:error, "Filtro no válido: '#{filtro}' (usa zona=, tipo=, prioridad= o estado=)"}}
      end
    end)
  end
end
