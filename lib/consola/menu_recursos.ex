defmodule Emergencia.Consola.MenuRecursos do
  @moduledoc """
  Gestiona las operaciones de recursos, existencias y necesidades.
  """

  alias Emergencia.Aplicacion.GestionRecursos
  alias Emergencia.Aplicacion.GestionResumen
  alias Emergencia.Aplicacion.GestionPersonas
  alias Emergencia.Aplicacion.GestionFamilias
  alias Emergencia.Aplicacion.GestionAlbergues
  alias Emergencia.Aplicacion.GestionTerritorio
  alias Emergencia.Aplicacion.GestionAlbergues
  alias Emergencia.AsignacionRecurso
  alias Emergencia.Consola.FormatoConsola
  alias Emergencia.Consola.PermisosMenu
  alias Emergencia.MovimientoRecurso
  alias Emergencia.Necesidad
  alias Emergencia.Recurso
  alias Util

  @tipos_necesidad %{
    "1" => :alimento,
    "2" => :medicina,
    "3" => :agua,
    "4" => :refugio,
    "5" => :personal,
    "6" => :transporte,
    "7" => :otro,
    "8" => :primeros_auxilios,
    "9" => :rescate
  }

  @prioridades %{"1" => :baja, "2" => :media, "3" => :alta, "4" => :critica}
  @estados %{
    "1" => :pendiente,
    "2" => :asignada,
    "3" => :en_atencion,
    "4" => :atendida,
    "5" => :cancelada
  }

  def iniciar(sesion) do
    Util.mostrar("\n========== GESTIÓN DE RECURSOS ==========", :mensaje)

    PermisosMenu.mostrar_opciones(sesion, [
      {"1", "Registrar necesidad", :crear_necesidad},
      {"2", "Registrar recurso e inventario", :asignar_recursos},
      {"3", "Asignar recurso a una necesidad", :asignar_recursos},
      {"4", "Transferir recurso", :transferir_recursos},
      {"5", "Listar existencias por ubicación", :consultar_recursos},
      {"6", "Listar todos los recursos y ubicaciones", :consultar_recursos},
      {"7", "Listar necesidades con filtros", :consultar_necesidades},
      {"8", "Consultar necesidades pendientes", :consultar_necesidades},
      {"9", "Listar necesidades ordenadas por prioridad", :consultar_necesidades},
      {"10", "Consultar stock global", :consultar_recursos},
      {"11", "Consultar recursos críticos", :consultar_recursos},
      {"12", "Volver al menú principal", nil}
    ])

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        registrar_necesidad(sesion)

      "2" ->
        registrar_recurso(sesion)

      "3" ->
        asignar_recurso(sesion)

      "4" ->
        transferir_recurso(sesion)

      "5" ->
        listar_existencias(sesion)

      "6" ->
        listar_todos_recursos(sesion)

      "7" ->
        listar_necesidades(sesion, [])

      "8" ->
        listar_necesidades(sesion, estado: :pendiente)

      "9" ->
        listar_necesidades_ordenadas(sesion)

      "10" ->
        consultar_stock(sesion)

      "11" ->
        consultar_criticos(sesion)

      "12" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida.", :error)
        iniciar(sesion)
    end
  end

  defp registrar_necesidad(sesion) do
    Util.mostrar(
      "Tipos: 1 alimento, 2 medicina, 3 agua, 4 refugio, 5 personal, " <>
        "6 transporte, 7 otro, 8 primeros_auxilios, 9 rescate",
      :mensaje
    )

    tipo = seleccionar(@tipos_necesidad, "Seleccione el tipo: ")
    cantidad = Util.ingresar("Cantidad requerida: ", :entero)
    prioridad = seleccionar(@prioridades, "Prioridad 1 baja, 2 media, 3 alta, 4 crítica: ")
    zona = Util.ingresar("Código de zona: ", :texto)
    destinatario = Util.ingresar("Código o documento del destinatario: ", :texto)
    descripcion = Util.ingresar("Descripción: ", :texto)

    with {:ok, tipo} <- tipo,
         {:ok, prioridad} <- prioridad do
      sesion
      |> GestionRecursos.registrar_necesidad(
        tipo,
        cantidad,
        zona,
        prioridad,
        destinatario,
        descripcion: descripcion
      )
      |> mostrar_resultado("Necesidad registrada:")
    else
      {:error, motivo} -> Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp registrar_recurso(sesion) do
    nombre = Util.ingresar("Nombre del recurso: ", :texto)

    Util.mostrar(
      "\nCategorías disponibles:",
      :mensaje
    )

    Util.mostrar("1. Agua", :mensaje)
    Util.mostrar("2. Alimentos", :mensaje)
    Util.mostrar("3. Medicamentos", :mensaje)
    Util.mostrar("4. Botiquines", :mensaje)
    Util.mostrar("5. Otro", :mensaje)

    opcion_categoria =
      Util.ingresar("Seleccione la categoría: ", :entero)

    categoria =
      case opcion_categoria do
        1 -> :agua
        2 -> :alimentos
        3 -> :medicamentos
        4 -> :botiquines
        5 -> :otro
        _ -> nil
      end

    if is_nil(categoria) do
      Util.mostrar("\nLa categoría seleccionada no es válida.", :mensaje)
    else
      cantidad = Util.ingresar("Cantidad inicial: ", :entero)
      unidad = Util.ingresar("Unidad de medida: ", :texto)

      ubicacion =
        Util.ingresar(
          "Código de centro, punto de atención o albergue: ",
          :texto
        )

      sesion
      |> GestionRecursos.registrar_recurso(
        nombre,
        categoria,
        cantidad,
        unidad,
        ubicacion
      )
      |> mostrar_resultado("Recurso registrado:")
    end

    iniciar(sesion)
  end

  defp asignar_recurso(sesion) do
    necesidad = Util.ingresar("Código de necesidad: ", :texto)
    recurso = Util.ingresar("Código de recurso: ", :texto)
    cantidad = Util.ingresar("Cantidad a asignar: ", :entero)

    sesion
    |> GestionRecursos.asignar_recurso(necesidad, recurso, cantidad)
    |> mostrar_resultado("Asignación realizada:")

    iniciar(sesion)
  end

  defp transferir_recurso(sesion) do
    recurso = Util.ingresar("Código de recurso: ", :texto)
    origen = Util.ingresar("Código de ubicación de origen: ", :texto)
    destino = Util.ingresar("Código de ubicación de destino: ", :texto)
    cantidad = Util.ingresar("Cantidad a transferir: ", :entero)

    sesion
    |> GestionRecursos.transferir_recurso(recurso, origen, destino, cantidad)
    |> mostrar_transferencia(recurso, origen, destino)

    iniciar(sesion)
  end

  defp listar_existencias(sesion) do
    ubicacion = Util.ingresar("Código de ubicación (vacío para todas): ", :texto)
    ubicacion = if ubicacion == "", do: nil, else: ubicacion

    case GestionRecursos.listar_recursos(sesion, ubicacion) do
      {:ok, existencias} -> mostrar_existencias(existencias)
      {:error, motivo} -> Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp listar_todos_recursos(sesion) do
    case GestionRecursos.listar_todos_recursos(sesion) do
      {:ok, recursos} -> mostrar_existencias(recursos)
      {:error, motivo} -> Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp listar_necesidades(sesion, filtros_iniciales) do
    zona = Util.ingresar("Filtro de zona (vacío para todas): ", :texto)
    tipo = seleccionar_opcional(@tipos_necesidad, "Filtro de tipo (vacío para omitir): ")
    prioridad = seleccionar_opcional(@prioridades, "Filtro de prioridad (vacío para omitir): ")

    estado =
      if Keyword.has_key?(filtros_iniciales, :estado),
        do: nil,
        else: seleccionar_opcional(@estados, "Filtro de estado (vacío para omitir): ")

    opciones =
      filtros_iniciales
      |> agregar_filtro(:zona, opcional(zona))
      |> agregar_filtro(:tipo, tipo)
      |> agregar_filtro(:prioridad, prioridad)
      |> agregar_filtro(:estado, estado)

    case GestionRecursos.listar_necesidades(sesion, opciones) do
      {:ok, necesidades} ->
        necesidades_enriquecidas = enriquecer_necesidades(necesidades, sesion)
        mostrar_necesidades(necesidades_enriquecidas)

      {:error, motivo} ->
        Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp listar_necesidades_ordenadas(sesion) do
    case GestionRecursos.listar_necesidades_ordenadas(sesion) do
      {:ok, necesidades} ->
        necesidades_enriquecidas = enriquecer_necesidades(necesidades, sesion)
        mostrar_necesidades(necesidades_enriquecidas)

      {:error, motivo} ->
        Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp consultar_stock(sesion) do
    recurso = Util.ingresar("Código de recurso: ", :texto)

    case GestionRecursos.calcular_stock_global(sesion, recurso) do
      {:ok, cantidad} -> Util.mostrar("Stock global: #{cantidad}", :mensaje)
      {:error, motivo} -> Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp consultar_criticos(sesion) do
    case GestionResumen.recursos_criticos(sesion) do
      {:ok, []} ->
        Util.mostrar("No hay existencias por debajo del umbral crítico.", :mensaje)

      {:ok, recursos} ->
        Enum.each(recursos, fn recurso ->
          Util.mostrar(
            "#{recurso.codigo} | #{recurso.nombre} | #{recurso.ubicacion} | " <>
              "#{recurso.cantidad} #{recurso.unidad_medida}",
            :mensaje
          )
        end)

      {:error, motivo} ->
        Util.mostrar(inspect(motivo), :error)
    end

    iniciar(sesion)
  end

  defp mostrar_existencias([]), do: Util.mostrar("No hay existencias registradas.", :mensaje)

  defp mostrar_existencias(existencias) do
    Enum.each(existencias, fn recurso ->
      ubicacion = Map.get(recurso, :ubicacion) || "Sin ubicación"

      Util.mostrar(
        "#{recurso.codigo} | #{recurso.nombre} | #{ubicacion} | " <>
          "#{recurso.cantidad} #{recurso.unidad_medida}",
        :mensaje
      )
    end)
  end

  defp mostrar_necesidades([]), do: Util.mostrar("No hay necesidades que coincidan.", :mensaje)

  defp mostrar_necesidades(necesidades) do
    Enum.each(necesidades, fn necesidad ->
      destinatario =
        if Map.has_key?(necesidad, :nombre_destinatario) do
          "#{necesidad.nombre_destinatario} (#{necesidad.codigo_destinatario})"
        else
          "No especificado"
        end

      Util.mostrar(
        "#{necesidad.codigo_necesidad} | #{FormatoConsola.estado(necesidad.tipo)} | " <>
          "Prioridad: #{FormatoConsola.estado(necesidad.prioridad)} | " <>
          "Pendiente: #{necesidad.cantidad_pendiente} | " <>
          "Destinatario: #{destinatario} | " <>
          "Estado: #{FormatoConsola.estado(necesidad.estado)}",
        :mensaje
      )
    end)
  end

  defp enriquecer_necesidades(necesidades, sesion) do
    Enum.map(necesidades, fn necesidad ->
      {nombre, codigo} = resolver_destinatario(necesidad, sesion)
      Map.merge(necesidad, %{nombre_destinatario: nombre, codigo_destinatario: codigo})
    end)
  end

  defp resolver_destinatario(%{id_destinatario: id_dest, entidad_asociada: tipo}, sesion)
       when not is_nil(id_dest) do
    case tipo do
      "persona" ->
        case GestionPersonas.buscar_personas(sesion, []) do
          {:ok, personas} ->
            case Enum.find(personas, &(&1.id == id_dest)) do
              nil -> {"Desconocido", id_dest}
              persona -> {persona.nombre, persona.codigo_persona}
            end

          _ ->
            {"Desconocido", id_dest}
        end

      "familia" ->
        case GestionFamilias.listar_familias(sesion) do
          {:ok, familias} ->
            case Enum.find(familias, &(&1.id == id_dest)) do
              nil -> {"Desconocida", id_dest}
              familia -> {familia.nombre, familia.codigo_familia}
            end

          _ ->
            {"Desconocida", id_dest}
        end

      "albergue" ->
        case GestionAlbergues.listar_albergues(sesion) do
          {:ok, albergues} ->
            case Enum.find(albergues, &(&1.id == id_dest)) do
              nil -> {"Desconocido", id_dest}
              albergue -> {albergue.nombre, albergue.codigo}
            end

          _ ->
            {"Desconocido", id_dest}
        end

      "zona" ->
        case GestionTerritorio.listar_zonas(sesion) do
          {:ok, zonas} ->
            case Enum.find(zonas, &(&1.id == id_dest)) do
              nil -> {"Desconocida", id_dest}
              zona -> {zona.nombre, zona.codigo_zona}
            end

          _ ->
            {"Desconocida", id_dest}
        end

      "centro_acopio" ->
        case GestionTerritorio.listar_centros_acopio(sesion) do
          {:ok, centros} ->
            case Enum.find(centros, &(&1.id == id_dest)) do
              nil -> {"Desconocido", id_dest}
              centro -> {centro.nombre, centro.codigo_centro_acopio}
            end

          _ ->
            {"Desconocido", id_dest}
        end

      "punto_atencion" ->
        case GestionTerritorio.listar_zonas(sesion) do
          {:ok, zonas} ->
            puntos = zonas |> Enum.flat_map(& &1.sectores) |> Enum.flat_map(& &1.puntos_atencion)

            case Enum.find(puntos, &(&1.id == id_dest)) do
              nil -> {"Desconocido", id_dest}
              punto -> {punto.nombre, punto.codigo_punto_atencion}
            end

          _ ->
            {"Desconocido", id_dest}
        end

      _ ->
        {"Desconocido", id_dest}
    end
  end

  defp resolver_destinatario(_necesidad, _sesion), do: {"Sin especificar", "N/A"}

  defp seleccionar(opciones, mensaje) do
    opciones
    |> seleccionar_opcion(Util.ingresar(mensaje, :texto))
  end

  defp seleccionar_opcional(opciones, mensaje) do
    case Util.ingresar(mensaje, :texto) do
      "" ->
        nil

      opcion ->
        case seleccionar_opcion(opciones, opcion) do
          {:ok, valor} ->
            valor

          {:error, motivo} ->
            Util.mostrar(motivo, :error)
            seleccionar_opcional(opciones, mensaje)
        end
    end
  end

  defp seleccionar_opcion(opciones, opcion) do
    case Map.fetch(opciones, opcion) do
      {:ok, valor} -> {:ok, valor}
      :error -> {:error, "Opción no válida."}
    end
  end

  defp agregar_filtro(filtros, _campo, nil), do: filtros
  defp agregar_filtro(filtros, campo, valor), do: Keyword.put(filtros, campo, valor)
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

  defp mostrar_transferencia({:ok, %MovimientoRecurso{} = movimiento}, recurso, origen, destino) do
    Util.mostrar("Transferencia realizada correctamente.", :mensaje)
    Util.mostrar("Recurso: #{recurso}", :mensaje)
    Util.mostrar("Origen: #{origen}", :mensaje)
    Util.mostrar("Destino: #{destino}", :mensaje)
    Util.mostrar("Cantidad: #{movimiento.cantidad}", :mensaje)
    Util.mostrar("Fecha y hora: #{FormatoConsola.fecha_hora(movimiento.fecha)}", :mensaje)
  end

  defp mostrar_transferencia(
         {:ok, %MovimientoRecurso{} = movimiento, {:advertencia, motivo}},
         recurso,
         origen,
         destino
       ) do
    mostrar_transferencia({:ok, movimiento}, recurso, origen, destino)
    Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)
  end

  defp mostrar_transferencia({:error, motivo}, _recurso, _origen, _destino) do
    Util.mostrar("No se pudo completar la transferencia: #{inspect(motivo)}", :error)
  end

  defp mostrar_detalle(%Necesidad{} = necesidad) do
    Util.mostrar("Código: #{necesidad.codigo_necesidad}", :mensaje)
    Util.mostrar("Tipo: #{FormatoConsola.estado(necesidad.tipo)}", :mensaje)
    Util.mostrar("Cantidad requerida: #{necesidad.cantidad_requerida}", :mensaje)
    Util.mostrar("Prioridad: #{FormatoConsola.estado(necesidad.prioridad)}", :mensaje)
    Util.mostrar("Estado: #{FormatoConsola.estado(necesidad.estado)}", :mensaje)
  end

  defp mostrar_detalle(%Recurso{} = recurso) do
    Util.mostrar("Código: #{recurso.codigo}", :mensaje)
    Util.mostrar("Nombre: #{recurso.nombre}", :mensaje)
    Util.mostrar("Unidad de medida: #{recurso.unidad_medida}", :mensaje)
  end

  defp mostrar_detalle(%MovimientoRecurso{} = movimiento) do
    Util.mostrar("Cantidad: #{movimiento.cantidad}", :mensaje)
    Util.mostrar("Fecha y hora: #{FormatoConsola.fecha_hora(movimiento.fecha)}", :mensaje)
  end

  defp mostrar_detalle(asignaciones) when is_list(asignaciones) do
    Enum.each(asignaciones, fn
      %AsignacionRecurso{} = asignacion ->
        Util.mostrar("Cantidad asignada: #{asignacion.cantidad_asignada}", :mensaje)
        Util.mostrar("Estado: #{FormatoConsola.estado(asignacion.estado)}", :mensaje)

        Util.mostrar(
          "Fecha: #{FormatoConsola.fecha_hora(asignacion.fecha_asignada)}",
          :mensaje
        )
    end)
  end
end
