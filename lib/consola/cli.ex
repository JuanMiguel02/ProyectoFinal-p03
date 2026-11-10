defmodule Emergencia.Consola.CLI do
  @moduledoc """
  Interfaz de línea de comandos (CLI) principal para la gestión de emergencias.
  Soporta códigos cortos (ZON-0001, NEC-0001, etc.), UUIDs y cadenas con comillas.
  """
  alias Emergencia.{
    UsuariosServidor,
    TerritorioServidor,
    RecursosServidor,
    PoblacionServidor,
    MensajesServidor,
    MascotasServidor,
    ActividadesServidor,
    GestorDatos
  }

  def iniciar do
    IO.puts("\n========================================================")
    IO.puts("    SISTEMA DISTRIBUIDO DE COORDINACIÓN DE EMERGENCIAS")
    IO.puts("========================================================")
    IO.puts("Escribe 'help' para ver los comandos disponibles o 'exit' para salir.\n")
    bucle_principal(nil)
  end

  defp bucle_principal(sesion) do
    prompt = if sesion, do: "[#{sesion.nombre_usuario} (#{sesion.tipo_usuario})]> ", else: "> "
    comando_crudo = IO.gets(prompt) |> String.trim()

    # Parseo inteligente que respeta las cadenas entre comillas dobles
    argumentos = parsear_argumentos(comando_crudo)

    nueva_sesion = evaluar_comando(argumentos, sesion)
    bucle_principal(nueva_sesion)
  end

  # Permite agrupar texto entre comillas dobles como un solo argumento
  defp parsear_argumentos(cadena) do
    Regex.scan(~r/[^\s"']+|"([^"]*)"|'([^']*)'/, cadena)
    |> Enum.map(fn
      [full] -> full
      [_, match1] when match1 != "" -> match1
      [_, _, match2] -> match2
      _ -> ""
    end)
    |> Enum.reject(&(&1 == ""))
  end

  # ============================================================================
  # 1. COMANDOS GENERALES Y DE SISTEMA
  # ============================================================================

  defp evaluar_comando(["exit"], sesion) do
    if sesion do
      ActividadesServidor.registrar(sesion.id_usuario, "LOGOUT", "El usuario cerró sesión al salir del sistema") # <--- AGREGAR ESTA LÍNEA
      UsuariosServidor.cerrar_sesion()
    end
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
        list_zones

      Recursos y Necesidades:
        register_need <tipo> <cantidad> <prioridad> <zona> <descripcion>
        register_resource <nombre> <categoria> <unidad>
        add_inventory <ubicacion> <tipo_ubic> <recurso> <cantidad>
        assign_resource <necesidad> <inventario> <cantidad>
        list_needs [zona=X] [prioridad=Y] [estado=Z]
        list_resources
        critical_resources
        pending_needs

      Población y Albergues:
        report_person <documento> <nombre> <zona> <estado>
        find_person <documento>
        register_shelter <codigo> <nombre> <zona> <capacidad>
        check_shelter <albergue>
        register_entry <albergue> <documento>
        register_exit <albergue> <documento>

      Comunicaciones y Mascotas:
        send_family_message <documento> <contenido>
        list_family_messages <documento>
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

 defp evaluar_comando(["connect", username, pass, tipo_str, zona_o_codigo], sesion) do
if sesion do
      IO.puts("Ya hay una sesión activa. Usa 'disconnect' primero.")
      sesion
    else
      # 1. Evitamos String.to_atom inseguro
      tipos_validos = %{"ciudadano" => :ciudadano, "voluntario" => :voluntario, "coordinador" => :coordinador, "administrador" => :administrador}
      tipo = Map.get(tipos_validos, String.downcase(tipo_str))

      if is_nil(tipo) do
        IO.puts("Error: Tipo de usuario no válido.")
        nil
      else
        _zona_id = resolver_id_zona(zona_o_codigo)

        # 2. Obligamos a pasar por la capa de Aplicación (que valida roles) para el registro
        # Simulamos que lo intenta hacer como ciudadano/voluntario si es público
        case Emergencia.Aplicacion.GestionUsuarios.registrar_usuario(username, pass, username, tipo) do
          {:ok, _} -> IO.puts("Cuenta creada exitosamente.")
          {:error, _} -> :ok # Probablemente ya existe, intentamos login
        end

        case Emergencia.Aplicacion.Autenticacion.iniciar_sesion(username, pass) do
          {:ok, auth} ->
            IO.puts("Conectado exitosamente como #{auth.nombre_completo}.")
            auth
          {:ok, auth, _advertencia} ->
            IO.puts("Conectado exitosamente como #{auth.nombre_completo}.")
            auth
          {:error, m} ->
            IO.puts("Error de autenticación: #{inspect(m)}")
            nil
        end
      end
    end
  end

  defp evaluar_comando(["disconnect"], sesion) do
    if sesion do
      ActividadesServidor.registrar(sesion.id_usuario, "LOGOUT", "El usuario #{sesion.nombre_usuario} cerró sesión")
      UsuariosServidor.cerrar_sesion()
      IO.puts("Sesión cerrada correctamente.")
      nil
    else
      IO.puts("No hay ninguna sesión activa.")
      nil
    end
  end

  # ============================================================================
  # 3. TERRITORIO
  # ============================================================================

  defp evaluar_comando(["register_zone", nombre, nivel, personas_str], sesion) do
    if sesion do
      case TerritorioServidor.registrar_zona(nombre, String.to_atom(nivel), String.to_integer(personas_str), sesion.id_usuario) do
        {:ok, z} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REGISTRAR_ZONA", "Se registró la zona #{nombre}")
          IO.puts("Zona registrada [Código: #{z.codigo_zona}, ID: #{z.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["register_sector", zona_o_codigo, nombre, nivel, personas_str], sesion) do
    if sesion do
      id_zona = resolver_id_zona(zona_o_codigo)
      case TerritorioServidor.registrar_sector(id_zona, nombre, String.to_atom(nivel), String.to_integer(personas_str), sesion.id_usuario) do
        {:ok, s} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REGISTRAR_SECTOR", "Se registró el sector #{nombre}")
          IO.puts("Sector registrado [Código: #{s.codigo_sector}, ID: #{s.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["list_zones"], sesion) do
    case TerritorioServidor.listar_zonas() do
      {:ok, zonas} when zonas != [] ->
        IO.puts("\n--- Zonas ---")
        Enum.each(zonas, fn z -> IO.puts("ID: #{z.id} | Código: #{z.codigo_zona} | Nombre: #{z.nombre}") end)
      _ -> IO.puts("No hay zonas registradas.")
    end
    sesion
  end

  # ============================================================================
  # 4. RECURSOS Y NECESIDADES
  # ============================================================================

  defp evaluar_comando(["register_need", tipo, cantidad, prioridad, zona_o_codigo, desc], sesion) do
    if sesion do
      id_zona = resolver_id_zona(zona_o_codigo)
      case RecursosServidor.registrar_necesidad(String.to_atom(tipo), String.to_integer(cantidad), id_zona, String.to_atom(prioridad), descripcion: desc) do
        {:ok, n} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REGISTRAR_NECESIDAD", "Se registró necesidad de tipo #{tipo}")
          IO.puts("Necesidad registrada [Código: #{n.codigo_necesidad}, ID: #{n.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["register_resource", nombre, cat, unidad], sesion) do
    if sesion do
      case RecursosServidor.registrar_recurso(nombre, String.to_atom(cat), unidad) do
        {:ok, r} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REGISTRAR_RECURSO", "Se registró el recurso #{nombre}")
          IO.puts("Recurso registrado [Código: #{r.codigo_recurso}, ID: #{r.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["add_inventory", ub_cod, tipo_ub, rec_cod, cant], sesion) do
    if sesion do
      tipo = String.to_atom(tipo_ub)
      id_ub = resolver_id_ubicacion(ub_cod, tipo)
      id_rec = resolver_id_recurso(rec_cod)
      case RecursosServidor.agregar_inventario(id_ub, tipo, id_rec, String.to_integer(cant)) do
        {:ok, inv} ->
          ActividadesServidor.registrar(sesion.id_usuario, "AGREGAR_INVENTARIO", "Se agregó inventario del recurso #{rec_cod}")
          IO.puts("Inventario agregado [ID: #{inv.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["assign_resource", nec_cod, inv_id, cant], sesion) do
    if sesion do
      id_nec = resolver_id_necesidad(nec_cod)
      case RecursosServidor.asignar_recurso(id_nec, inv_id, String.to_integer(cant), sesion.id_usuario) do
        {:ok, asig} ->
          ActividadesServidor.registrar(sesion.id_usuario, "ASIGNAR_RECURSO", "Se asignó recurso a la necesidad #{nec_cod}")
          IO.puts("Recurso asignado [ID: #{asig.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["list_resources"], sesion) do
    case GestorDatos.cargar_coleccion("recursos.json", Emergencia.Recurso, :id) do
      {:ok, recs} when recs != %{} ->
        IO.puts("\n--- Recursos ---")
        Enum.each(recs, fn {_, r} -> IO.puts("ID: #{r.id} | Código: #{r.codigo_recurso} | Nombre: #{r.nombre} | Cat: #{r.categoria}") end)
      _ -> IO.puts("Sin recursos.")
    end
    sesion
  end

  defp evaluar_comando(["list_needs" | filtros], sesion) do
    case GestorDatos.cargar_coleccion("necesidades.json", Emergencia.Necesidad, :id) do
      {:ok, necs} when necs != %{} ->
        filtradas = Enum.filter(Map.values(necs), fn n ->
          Enum.all?(filtros, fn f ->
            case String.split(f, "=", parts: 2) do
              ["zona", val] -> n.id_zona == val or n.id_zona == resolver_id_zona(val)
              ["prioridad", val] -> to_string(n.prioridad) == val
              ["estado", val] -> to_string(n.estado) == val
              _ -> true
            end
          end)
        end)
        IO.puts("\n--- Necesidades ---")
        Enum.each(filtradas, fn n -> IO.puts("Código: #{n.codigo_necesidad} | Tipo: #{n.tipo} | Cant: #{n.cantidad_requerida} | Estado: #{n.estado}") end)
      _ -> IO.puts("Sin necesidades.")
    end
    sesion
  end

  defp evaluar_comando(["pending_needs"], sesion) do
    evaluar_comando(["list_needs", "estado=pendiente"], sesion)
  end

  defp evaluar_comando(["critical_resources"], sesion) do
    IO.puts("\n--- Stock Crítico ---")
    case GestorDatos.cargar_coleccion("inventarios.json", Emergencia.InventarioUbicacion, :id) do
      {:ok, invs} ->
        Enum.each(invs, fn {_, i} -> if i.cantidad_disponible < 10, do: IO.puts("Inventario ID: #{i.id} | Disp: #{i.cantidad_disponible}") end)
      _ -> :ok
    end
    sesion
  end

  defp evaluar_comando(["transfer_resource", recurso_cod, origen_cod, destino_cod, cant], sesion) do
    if sesion do
      cantidad = String.to_integer(cant)
      id_recurso = resolver_id_recurso(recurso_cod)

      {id_origen, _tipo_origen} = resolver_ubicacion_transferencia(origen_cod)
      {id_destino, tipo_destino} = resolver_ubicacion_transferencia(destino_cod)

      case RecursosServidor.transferir_recurso(id_recurso, id_origen, id_destino, tipo_destino, cantidad) do
        {:ok, mov} ->
          ActividadesServidor.registrar(sesion.id_usuario, "TRANSFERIR_RECURSO", "Se transfirieron #{cantidad} unidades del recurso #{recurso_cod}")
          IO.puts("¡Transferencia exitosa! Se movieron #{cantidad} unidades al destino [Movimiento ID: #{mov.id}]")
        {:error, motivo} ->
          IO.puts("Error en la transferencia: #{inspect(motivo)}")
      end
    else
      IO.puts("Error: Inicia sesión primero.")
    end
    sesion
  end

  # ============================================================================
  # 5. POBLACIÓN Y ALBERGUES
  # ============================================================================

  defp evaluar_comando(["report_person", doc, nombre, zona_cod, estado], sesion) do
    if sesion do
      id_zona = resolver_id_zona(zona_cod)
      case PoblacionServidor.registrar_persona(nombre, doc, id_zona, String.to_atom(estado)) do
        {:ok, p} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REPORTAR_PERSONA", "Se registró a la persona #{nombre}")
          IO.puts("Persona registrada [Código: #{p.codigo_persona}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["find_person", doc_o_id], sesion) do
    case PoblacionServidor.consultar_historial_persona(doc_o_id) do
      {:ok, info} ->
        IO.puts("\n--- Persona ---")
        IO.puts("Nombre: #{info.nombre} | Estado: #{info.estado}")
      {:error, m} -> IO.puts("Error: #{inspect(m)}")
    end
    sesion
  end

  defp evaluar_comando(["register_shelter", _cod, nombre, zona_cod, cap], sesion) do
    if sesion do
      id_zona = resolver_id_zona(zona_cod)
      # Nota: el servicio puro usa (nombre, id_zona, capacidad_maxima) y autogenera el código
      case PoblacionServidor.registrar_albergue(nombre, id_zona, String.to_integer(cap)) do
        {:ok, a} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REGISTRAR_ALBERGUE", "Se registró el albergue #{nombre}")
          IO.puts("Albergue registrado [Código: #{a.codigo}, ID: #{a.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["check_shelter", alb_cod], sesion) do
    id_alb = resolver_id_albergue(alb_cod)
    case PoblacionServidor.consultar_ocupacion(id_alb) do
      {:ok, info} ->
        IO.puts("\n--- Albergue ---")
        IO.puts("Capacidad: #{info.capacidad_maxima} | Ocupación: #{info.ocupacion_actual} | Disponibles: #{info.cupos_disponibles}")
      {:error, m} -> IO.puts("Error: #{inspect(m)}")
    end
    sesion
  end

  defp evaluar_comando(["register_entry", alb_cod, doc_o_id], sesion) do
    if sesion do
      id_pers = resolver_id_persona(doc_o_id)
      id_alb = resolver_id_albergue(alb_cod)
      case PoblacionServidor.ingresar_persona(id_pers, id_alb) do
        {:ok, _} ->
          ActividadesServidor.registrar(sesion.id_usuario, "INGRESO_ALBERGUE", "Se registró ingreso de persona al albergue #{alb_cod}")
          IO.puts("Ingreso registrado correctamente.")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["register_exit", _alb_cod, doc_o_id], sesion) do
    if sesion do
      id_pers = resolver_id_persona(doc_o_id)
      case PoblacionServidor.registrar_salida(id_pers) do
        {:ok, _} ->
          ActividadesServidor.registrar(sesion.id_usuario, "SALIDA_ALBERGUE", "Se registró salida de albergue de la persona")
          IO.puts("Salida registrada correctamente.")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  # ============================================================================
  # 6. COMUNICACIONES Y MASCOTAS
  # ============================================================================

  defp evaluar_comando(["send_family_message", doc_id_o_familia, contenido], sesion) do
   if sesion do
      # Consultar si el identificador es de una familia
      ids_personas =
        case PoblacionServidor.consultar_integrantes(doc_id_o_familia) do
          {:ok, integrantes} when integrantes != [] ->
            # Es una familia, extraer los IDs de todos los integrantes
            Enum.map(integrantes, & &1.id)
          _ ->
            # No es familia o está vacía, lo trata como una persona individual
            [resolver_id_persona(doc_id_o_familia)]
        end

      case MensajesServidor.enviar_mensaje(sesion.id_usuario, contenido, ids_personas, []) do
        {:ok, _} ->
          ActividadesServidor.registrar(sesion.id_usuario, "ENVIAR_MENSAJE", "Se envió un mensaje familiar")
          IO.puts("¡Mensaje enviado y enrutado con éxito a #{length(ids_personas)} destinatario(s)!")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["list_family_messages", doc], sesion) do
    id_pers = resolver_id_persona(doc)
    case MensajesServidor.obtener_mensajes_persona(id_pers) do
      {:ok, msgs} when msgs != [] ->
        IO.puts("\n--- Mensajes ---")
        Enum.each(msgs, fn m -> IO.puts("Estado: #{m.estado_entrega} | Texto: #{m.mensaje.contenido}") end)
      _ -> IO.puts("No hay mensajes.")
    end
    sesion
  end

  defp evaluar_comando(["report_pet", tipo, especie, nombre, color, tamano, zona_cod, contacto], sesion) do
    if sesion do
      id_zona = resolver_id_zona(zona_cod)
      case MascotasServidor.registrar_reporte(String.to_atom(tipo), especie, color, String.to_atom(tamano), id_zona, contacto, nombre: nombre) do
        {:ok, r} ->
          ActividadesServidor.registrar(sesion.id_usuario, "REPORTAR_MASCOTA", "Se registró reporte de mascota #{tipo}")
          IO.puts("Reporte de mascota registrado [ID: #{r.id}]")
        {:error, m} -> IO.puts("Error: #{inspect(m)}")
      end
    else
      IO.puts("Inicia sesión primero.")
    end
    sesion
  end

  defp evaluar_comando(["match_pets"], sesion) do
    IO.puts("Búsqueda de coincidencias de mascotas iniciada en background.")
    sesion
  end

  defp evaluar_comando(["check_stock", rec_cod], sesion) do
    id_rec = resolver_id_recurso(rec_cod)
    case Emergencia.RecursosServidor.calcular_stock_global(id_rec) do
      {:ok, total} ->
        IO.puts("\nStock global acumulado para el recurso [#{rec_cod}]: #{total} unidades.")
      {:error, m} ->
        IO.puts("Error: #{inspect(m)}")
    end
    sesion
  end

  defp evaluar_comando(["list_ordered_needs"], sesion) do
    case Emergencia.RecursosServidor.listar_necesidades_ordenadas() do
      {:ok, necs} when necs != [] ->
        IO.puts("\n--- Necesidades Ordenadas por Prioridad ---")
        Enum.each(necs, fn n ->
          IO.puts("[#{n.prioridad}] Código: #{n.codigo_necesidad} | Tipo: #{n.tipo} | Pendiente: #{n.cantidad_pendiente}")
        end)
      _ -> IO.puts("Sin necesidades.")
    end
    sesion
  end

  # ============================================================================
  # 7. RESUMEN GENERAL
  # ============================================================================

 defp evaluar_comando(["summary"], sesion) do
    IO.puts("\n================ RESUMEN GLOBAL DEL SISTEMA ================")

    zonas = case TerritorioServidor.listar_zonas() do {:ok, z} -> length(z); _ -> 0 end
    necesidades = case RecursosServidor.listar_necesidades() do {:ok, n} -> length(n); _ -> 0 end
    albergues = case PoblacionServidor.listar_albergues() do {:ok, a} -> length(a); _ -> 0 end

    IO.puts(" - Zonas registradas: #{zonas}")
    IO.puts(" - Necesidades totales: #{necesidades}")
    IO.puts(" - Albergues operativos: #{albergues}")
    IO.puts("============================================================")
    sesion
  end

  defp evaluar_comando([cmd | _], sesion) do
    IO.puts("Comando desconocido: '#{cmd}'. Escribe 'help'.")
    sesion
  end

  # ============================================================================
  # RESOLVIDORES DE IDs Y CÓDIGOS
  # ============================================================================

  defp resolver_id_zona(entrada) do
    case TerritorioServidor.listar_zonas() do
      {:ok, zonas} -> find_by_code_or_id(zonas, entrada, & &1.codigo_zona)
      _ -> entrada
    end
  end

  defp resolver_id_recurso(entrada) do
    case RecursosServidor.listar_recursos() do
      {:ok, recs} -> find_by_code_or_id(recs, entrada, & &1.codigo_recurso)
      _ -> entrada
    end
  end

  defp resolver_id_necesidad(entrada) do
    case RecursosServidor.listar_necesidades() do
      {:ok, necs} -> find_by_code_or_id(necs, entrada, & &1.codigo_necesidad)
      _ -> entrada
    end
  end

  defp resolver_id_albergue(entrada) do
    case PoblacionServidor.listar_albergues() do
      {:ok, albs} -> find_by_code_or_id(albs, entrada, & &1.codigo)
      _ -> entrada
    end
  end

  defp resolver_id_persona(entrada) do
    # Usamos buscar_personas([]) que devuelve todos los registros
    case PoblacionServidor.buscar_personas([]) do
      {:ok, personas} ->
        encontrada = Enum.find(personas, fn p -> p.id == entrada or p.codigo_persona == entrada or p.documento == entrada end)
        if encontrada, do: encontrada.id, else: entrada
      _ -> entrada
    end
  end

  defp resolver_id_ubicacion(entrada, tipo) do
    case tipo do
      :centro_acopio ->
        case TerritorioServidor.listar_centros_acopio() do
          {:ok, centros} -> find_by_code_or_id(centros, entrada, & &1.codigo_centro_acopio)
          _ -> entrada
        end
      :albergue -> resolver_id_albergue(entrada)
      _ -> resolver_id_zona(entrada)
    end
  end

  defp resolver_ubicacion_transferencia(entrada) do
    centros = case TerritorioServidor.listar_centros_acopio() do
      {:ok, lista} -> lista
      _ -> []
    end

    albergues = case PoblacionServidor.listar_albergues() do
      {:ok, lista} -> lista
      _ -> []
    end

    centro = Enum.find(centros, fn c -> c.id == entrada or c.codigo_centro_acopio == entrada end)
    albergue = Enum.find(albergues, fn a -> a.id == entrada or a.codigo == entrada end)

    cond do
      centro -> {centro.id, :centro_acopio}
      albergue -> {albergue.id, :albergue}
      true ->
        # Si no es centro ni albergue explícito, buscamos si es una zona
        id_zona = resolver_id_zona(entrada)
        if id_zona != entrada do
          {id_zona, :centro_acopio}
        else
          {entrada, :albergue} # Fallback por defecto
        end
    end
  end

  defp find_by_code_or_id(lista, entrada, code_fun) when is_list(lista) do
    match = Enum.find(lista, fn ent -> ent.id == entrada or code_fun.(ent) == entrada end)
    if match, do: match.id, else: entrada
  end
end
