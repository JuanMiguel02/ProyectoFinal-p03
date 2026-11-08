defmodule Emergencia.Servicios.ServicioRecursos do
  @moduledoc """
  Servicio puro para la gestión de recursos, inventarios, necesidades y asignaciones.
  """
  alias Emergencia.{Necesidad, Recurso, InventarioUbicacion, AsignacionRecurso, MovimientoRecurso}

  def registrar_necesidad(estado, tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    with {:ok, necesidad} <- Necesidad.nueva(tipo, cantidad, id_zona, prioridad, opciones) do
      nuevas_necesidades = Map.put(estado.necesidades, necesidad.id, necesidad)
      nuevo_estado = %{estado | necesidades: nuevas_necesidades}
      {:ok, necesidad, nuevo_estado}
    end
  end

  def registrar_recurso(estado, codigo, nombre, categoria, unidad_medida) do
    with {:ok, recurso} <- Recurso.nuevo(codigo, nombre, categoria, unidad_medida) do
      nuevos_recursos = Map.put(estado.recursos, recurso.id, recurso)
      nuevo_estado = %{estado | recursos: nuevos_recursos}
      {:ok, recurso, nuevo_estado}
    end
  end

  def agregar_inventario(estado, id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
    with {:ok, inventario} <- InventarioUbicacion.nueva(id_ubicacion, tipo_ubicacion, id_recurso, cantidad),
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
