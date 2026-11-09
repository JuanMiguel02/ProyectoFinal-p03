defmodule Emergencia.Servicios.ServicioRecursos do
  @moduledoc """
  Servicio puro para la gestión de recursos, inventarios, necesidades y asignaciones.
  """
  alias Emergencia.{Necesidad, Recurso, InventarioUbicacion, AsignacionRecurso, MovimientoRecurso, GeneradorID}

  def registrar_necesidad(estado, tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    codigo_necesidad = GeneradorID.generar("NEC", estado.necesidades, & &1.codigo_necesidad)
    with {:ok, necesidad} <- Necesidad.nueva(codigo_necesidad, tipo, cantidad, id_zona, prioridad, opciones) do
      nuevas_necesidades = Map.put(estado.necesidades, necesidad.id, necesidad)
      nuevo_estado = %{estado | necesidades: nuevas_necesidades}
      {:ok, necesidad, nuevo_estado}
    end
  end

  def registrar_recurso(estado, nombre, categoria, unidad_medida) do
    codigo_recurso = GeneradorID.generar("REC", estado.recursos, & &1.codigo_recurso)
    with {:ok, recurso} <- Recurso.nuevo(codigo_recurso, nombre, categoria, unidad_medida) do
      nuevos_recursos = Map.put(estado.recursos, recurso.id, recurso)
      nuevo_estado = %{estado | recursos: nuevos_recursos}
      {:ok, recurso, nuevo_estado}
    end
  end

  def agregar_inventario(estado, id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
    with {:ok, inventario} <- InventarioUbicacion.nuevo(id_ubicacion, tipo_ubicacion, id_recurso, cantidad),
         {:ok, movimiento} <- MovimientoRecurso.nuevo(cantidad, :ingreso, id_inventario_destino: inventario.id) do

      nuevo_estado = %{
        estado |
        inventarios: Map.put(estado.inventarios, inventario.id, inventario),
        movimientos_recursos: Map.put(estado.movimientos_recursos, movimiento.id, movimiento)
      }
      {:ok, inventario, nuevo_estado}
    end
  end

  def asignar_recurso(estado, id_necesidad, id_inventario, cantidad, _id_usuario \\ "SISTEMA") do
    with {:ok, necesidad} <- obtener_entidad(estado.necesidades, id_necesidad, "Necesidad"),
         {:ok, inventario} <- obtener_entidad(estado.inventarios, id_inventario, "Inventario"),
         :ok <- validar_necesidad_activa(necesidad),
         :ok <- validar_disponibilidad(inventario, cantidad),
         {:ok, asignacion} <- AsignacionRecurso.nueva(id_necesidad, id_inventario, cantidad),
         {:ok, movimiento} <- MovimientoRecurso.nuevo(cantidad, :asignacion, id_inventario_origen: id_inventario, id_asignacion: asignacion.id) do

      nuevo_inventario = %{inventario | cantidad_disponible: inventario.cantidad_disponible - cantidad}
      cantidad_restante = necesidad.cantidad_requerida - cantidad
      nuevo_estado_nec = if cantidad_restante <= 0, do: :cubierta, else: :en_proceso
      nueva_necesidad = %{necesidad | cantidad_requerida: max(0, cantidad_restante), estado: nuevo_estado_nec}

      estado_actualizado = %{
        estado |
        necesidades: Map.put(estado.necesidades, nueva_necesidad.id, nueva_necesidad),
        inventarios: Map.put(estado.inventarios, nuevo_inventario.id, nuevo_inventario),
        asignaciones_recursos: Map.put(estado.asignaciones_recursos, asignacion.id, asignacion),
        movimientos_recursos: Map.put(estado.movimientos_recursos, movimiento.id, movimiento)
      }

      {:ok, asignacion, estado_actualizado}
    end
  end

  @doc """
  Suma recursivamente la cantidad disponible de un recurso en todas las ubicaciones.
  """
  def calcular_stock_global(estado, id_recurso) do
    inventarios_lista = Map.values(estado.inventarios)
    total = sumar_stock_recursivo(inventarios_lista, id_recurso, 0)
    {:ok, total}
  end

  def transferir_recurso(estado, id_recurso, id_ubicacion_origen, id_ubicacion_destino, tipo_ubic_destino, cantidad) do
    # Buscamos el inventario exacto en la ubicación de origen
    inv_origen = Enum.find(Map.values(estado.inventarios), fn i ->
      i.id_recurso == id_recurso and i.id_ubicacion == id_ubicacion_origen
    end)

    if is_nil(inv_origen) do
      {:error, "No hay inventario registrado del recurso en el origen especificado"}
    else
      with :ok <- validar_disponibilidad(inv_origen, cantidad),
           {:ok, inv_destino} <- InventarioUbicacion.nuevo(id_ubicacion_destino, tipo_ubic_destino, id_recurso, cantidad),
           {:ok, movimiento} <- MovimientoRecurso.nuevo(cantidad, :transferencia, id_inventario_origen: inv_origen.id, id_inventario_destino: inv_destino.id) do

        nuevo_inv_origen = %{inv_origen | cantidad_disponible: inv_origen.cantidad_disponible - cantidad}

        nuevo_estado = %{
          estado |
          inventarios: estado.inventarios
                       |> Map.put(nuevo_inv_origen.id, nuevo_inv_origen)
                       |> Map.put(inv_destino.id, inv_destino),
          movimientos_recursos: Map.put(estado.movimientos_recursos, movimiento.id, movimiento)
        }

        {:ok, movimiento, nuevo_estado}
      end
    end
  end

  defp sumar_stock_recursivo([], _id_recurso, total_acumulado), do: total_acumulado
  defp sumar_stock_recursivo([inventario | resto], id_recurso, total_acumulado) do
    if inventario.id_recurso == id_recurso do
      sumar_stock_recursivo(resto, id_recurso, total_acumulado + inventario.cantidad_disponible)
    else
      sumar_stock_recursivo(resto, id_recurso, total_acumulado)
    end
  end

  defp obtener_entidad(mapa, id, nombre) do
    case Map.fetch(mapa, id) do
      {:ok, entidad} -> {:ok, entidad}
      :error -> {:error, "#{nombre} con ID '#{id}' no encontrada"}
    end
  end

  defp validar_necesidad_activa(%Necesidad{estado: estado}) when estado in [:cubierta, :cancelada] do
    {:error, "La necesidad ya está #{estado} y no puede consumir recursos"}
  end
  defp validar_necesidad_activa(_), do: :ok

  defp validar_disponibilidad(%InventarioUbicacion{cantidad_disponible: disponible}, requerida) do
    if disponible >= requerida do
      :ok
    else
      {:error, "Inventario insuficiente. Solicitado: #{requerida}, Disponible: #{disponible}"}
    end
  end
end
