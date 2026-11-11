defmodule Emergencia.Servicios.ServicioRecursos do
  @moduledoc """
  Servicio puro para la gestión de recursos, existencias, necesidades y asignaciones.
  """

  alias Emergencia.{
    AsignacionRecurso,
    EstadoRecursos,
    GeneradorID,
    MovimientoRecurso,
    Necesidad,
    Recurso
  }

    @categorias_permitidas [
    :agua,
    :alimentos,
    :medicamentos,
    :botiquines,
    :otro
  ]

  def registrar_necesidad(estado, tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    codigo_necesidad = GeneradorID.generar("NEC", estado.necesidades, & &1.codigo_necesidad)

    with {:ok, necesidad} <-
           Necesidad.nueva(codigo_necesidad, tipo, cantidad, id_zona, prioridad, opciones) do
      {:ok, necesidad,
       %{estado | necesidades: Map.put(estado.necesidades, necesidad.id, necesidad)}}
    end
  end

  def registrar_recurso(
        %EstadoRecursos{} = estado,
        nombre,
        categoria,
        cantidad,
        unidad,
        ubicacion
      ) do
    codigo = GeneradorID.generar("REC", estado.recursos, & &1.codigo)

    with :ok <- validar_texto(nombre, "El nombre del recurso"),
         :ok <- validar_categoria(categoria),
         :ok <- validar_texto(unidad, "La unidad de medida"),
         :ok <- validar_texto(ubicacion, "La ubicación"),
         :ok <- validar_cantidad(cantidad),
         {:ok, recurso} <- Recurso.nuevo(codigo, nombre, categoria, unidad),
         {:ok, movimiento} <-
           MovimientoRecurso.nuevo(cantidad, :ingreso,
             id_recurso: recurso.id,
             ubicacion_destino: ubicacion
           ) do
      clave = {recurso.codigo, ubicacion}

      nuevo_estado = %{
        estado
        | recursos: Map.put(estado.recursos, recurso.id, recurso),
          existencias: Map.update(estado.existencias, clave, cantidad, &(&1 + cantidad)),
          movimientos: Map.put(estado.movimientos, movimiento.id, movimiento)
      }

      {:ok, recurso, nuevo_estado}
    end
  end

  defp validar_categoria(categoria) do
    if categoria in @categorias_permitidas do
      :ok
    else
      {:error, "La categoría del recurso no es válida."}
    end
  end


  def listar_recursos(%EstadoRecursos{} = estado, filtros \\ %{}) do
    ubicacion = Map.get(filtros, :ubicacion)
    categoria = Map.get(filtros, :categoria)
    recursos_por_codigo = Map.new(Map.values(estado.recursos), &{&1.codigo, &1})

    existencias =
      estado.existencias
      |> Enum.filter(fn {{_codigo, lugar}, _cantidad} ->
        is_nil(ubicacion) or lugar == ubicacion
      end)
      |> Enum.map(fn {{codigo, lugar}, cantidad} ->
        recurso = Map.fetch!(recursos_por_codigo, codigo)

        %{
          id: recurso.id,
          codigo: recurso.codigo,
          nombre: recurso.nombre,
          categoria: recurso.categoria,
          unidad_medida: recurso.unidad_medida,
          ubicacion: lugar,
          cantidad: cantidad
        }
      end)
      |> Enum.filter(&(is_nil(categoria) or &1.categoria == categoria))
      |> Enum.sort_by(&{&1.codigo, &1.ubicacion})

    {:ok, existencias}
  end

  def listar_todos_recursos(%EstadoRecursos{} = estado) do
    recursos =
      estado.recursos
      |> Map.values()
      |> Enum.sort_by(& &1.codigo)
      |> Enum.flat_map(fn recurso ->
        existencias =
          estado.existencias
          |> Enum.filter(fn {{codigo, _ubicacion}, _cantidad} -> codigo == recurso.codigo end)
          |> Enum.map(fn {{_codigo, ubicacion}, cantidad} ->
            Map.merge(Map.from_struct(recurso), %{ubicacion: ubicacion, cantidad: cantidad})
          end)
          |> Enum.sort_by(& &1.ubicacion)

        case existencias do
          [] -> [Map.merge(Map.from_struct(recurso), %{ubicacion: nil, cantidad: 0})]
          _ -> existencias
        end
      end)

    {:ok, recursos}
  end

  def asignar_recurso(%EstadoRecursos{} = estado, codigo_recurso, cantidad) do
    with :ok <- validar_cantidad(cantidad),
         {:ok, recurso} <- obtener_recurso(estado.recursos, codigo_recurso),
         {:ok, origenes} <- seleccionar_origenes(estado.existencias, recurso.codigo, cantidad),
         {:ok, movimientos} <- crear_movimientos_asignacion(origenes, recurso.id) do
      existencias =
        Enum.reduce(origenes, estado.existencias, fn {ubicacion, asignada}, acc ->
          Map.update!(acc, {recurso.codigo, ubicacion}, &(&1 - asignada))
        end)

      nuevo_estado = %{
        estado
        | existencias: existencias,
          movimientos: Enum.reduce(movimientos, estado.movimientos, &Map.put(&2, &1.id, &1))
      }

      {:ok, movimientos, nuevo_estado}
    end
  end

  def asignar_a_necesidad(
        %EstadoRecursos{} = estado,
        id_necesidad,
        codigo_recurso,
        cantidad
      ) do
    with {:ok, _necesidad} <- validar_necesidad_directa(estado, id_necesidad, cantidad),
         {:ok, movimientos, estado_con_stock} <-
           asignar_recurso(estado, codigo_recurso, cantidad),
         origenes <-
           Enum.map(movimientos, &{&1.id_recurso, &1.ubicacion_origen, &1.cantidad}),
         {:ok, asignaciones, estado_actualizado} <-
           asignar_recurso_directo(estado_con_stock, id_necesidad, origenes, cantidad) do
      {:ok, asignaciones, estado_actualizado}
    end
  end

  def validar_necesidad_directa(estado, id_necesidad, cantidad) do
    with {:ok, necesidad} <- obtener_necesidad(estado.necesidades, id_necesidad),
         :ok <- validar_necesidad_activa(necesidad),
         :ok <- validar_cantidad_pendiente(necesidad, cantidad) do
      {:ok, necesidad}
    end
  end

  def asignar_recurso_directo(estado, id_necesidad, origenes, cantidad) do
    with {:ok, necesidad} <- validar_necesidad_directa(estado, id_necesidad, cantidad),
         {:ok, asignaciones} <- crear_asignaciones(id_necesidad, origenes),
         :ok <- validar_total_asignado(asignaciones, cantidad) do
      cantidad_restante = necesidad.cantidad_pendiente - cantidad

      necesidad_actualizada = %{
        necesidad
        | cantidad_pendiente: cantidad_restante,
          estado: if(cantidad_restante == 0, do: :atendida, else: :en_atencion)
      }

      asignaciones_actualizadas =
        Enum.reduce(asignaciones, estado.asignaciones, &Map.put(&2, &1.id, &1))

      nuevo_estado = %{
        estado
        | necesidades: Map.put(estado.necesidades, necesidad.id, necesidad_actualizada),
          asignaciones: asignaciones_actualizadas
      }

      {:ok, asignaciones, nuevo_estado}
    end
  end

  def transferir_recurso(
        %EstadoRecursos{} = estado,
        codigo_recurso,
        ubicacion_origen,
        ubicacion_destino,
        cantidad
      ) do
    with :ok <- validar_cantidad(cantidad),
         {:ok, recurso} <- obtener_recurso(estado.recursos, codigo_recurso),
         :ok <- validar_texto(ubicacion_origen, "La ubicación de origen"),
         :ok <- validar_texto(ubicacion_destino, "La ubicación de destino"),
         :ok <- validar_ubicaciones_distintas(ubicacion_origen, ubicacion_destino),
         clave_origen <- {recurso.codigo, ubicacion_origen},
         clave_destino <- {recurso.codigo, ubicacion_destino},
         disponible <- Map.get(estado.existencias, clave_origen, 0),
         :ok <- validar_disponibilidad(disponible, cantidad),
         {:ok, movimiento} <-
           MovimientoRecurso.nuevo(cantidad, :transferencia,
             id_recurso: recurso.id,
             ubicacion_origen: ubicacion_origen,
             ubicacion_destino: ubicacion_destino
           ) do
      existencias =
        estado.existencias
        |> Map.put(clave_origen, disponible - cantidad)
        |> Map.update(clave_destino, cantidad, &(&1 + cantidad))

      nuevo_estado = %{
        estado
        | existencias: existencias,
          movimientos: Map.put(estado.movimientos, movimiento.id, movimiento)
      }

      {:ok, movimiento, nuevo_estado}
    end
  end

  def calcular_stock_global(%EstadoRecursos{} = estado, codigo_recurso) do
    with {:ok, recurso} <- obtener_recurso(estado.recursos, codigo_recurso) do
      total =
        Enum.reduce(estado.existencias, 0, fn
          {{codigo, _ubicacion}, cantidad}, acc when codigo == recurso.codigo -> acc + cantidad
          _, acc -> acc
        end)

      {:ok, total}
    end
  end

  def listar_necesidades_ordenadas(estado) do
    jerarquia = %{critica: 4, alta: 3, media: 2, baja: 1}

    necesidades =
      estado.necesidades
      |> Map.values()
      |> Enum.sort_by(&Map.get(jerarquia, &1.prioridad, 0), :desc)

    {:ok, necesidades}
  end

  defp obtener_recurso(recursos, codigo) do
    case Enum.find(Map.values(recursos), &(&1.codigo == codigo or &1.id == codigo)) do
      nil -> {:error, "No se encontró el recurso '#{codigo}'"}
      recurso -> {:ok, recurso}
    end
  end

  defp seleccionar_origenes(existencias, codigo, cantidad) do
    resultado =
      existencias
      |> Enum.filter(fn {{codigo_existente, _ubicacion}, _stock} ->
        codigo_existente == codigo
      end)
      |> Enum.sort_by(fn {{_codigo, ubicacion}, _stock} -> ubicacion end)
      |> Enum.reduce_while({:ok, [], cantidad}, fn {{_codigo, ubicacion}, stock},
                                                   {:ok, origenes, restante} ->
        asignada = min(stock, restante)
        origenes = if asignada > 0, do: [{ubicacion, asignada} | origenes], else: origenes
        restante = restante - asignada

        if restante == 0,
          do: {:halt, {:ok, Enum.reverse(origenes), 0}},
          else: {:cont, {:ok, origenes, restante}}
      end)

    case resultado do
      {:ok, origenes, 0} ->
        {:ok, origenes}

      {:ok, _origenes, restante} ->
        disponible = cantidad - restante

        {:error, "Existencias insuficientes. Solicitado: #{cantidad}, disponible: #{disponible}"}
    end
  end

  defp crear_movimientos_asignacion(origenes, id_recurso) do
    Enum.reduce_while(origenes, {:ok, []}, fn {ubicacion, cantidad}, {:ok, acc} ->
      case MovimientoRecurso.nuevo(cantidad, :asignacion,
             id_recurso: id_recurso,
             ubicacion_origen: ubicacion
           ) do
        {:ok, movimiento} -> {:cont, {:ok, [movimiento | acc]}}
        {:error, motivo} -> {:halt, {:error, motivo}}
      end
    end)
    |> case do
      {:ok, movimientos} -> {:ok, Enum.reverse(movimientos)}
      error -> error
    end
  end

  defp obtener_necesidad(necesidades, id) do
    case Map.fetch(necesidades, id) do
      {:ok, necesidad} -> {:ok, necesidad}
      :error -> {:error, "Necesidad con ID '#{id}' no encontrada"}
    end
  end

  defp validar_necesidad_activa(%Necesidad{estado: estado})
       when estado in [:atendida, :cancelada],
       do: {:error, "La necesidad ya está #{estado} y no puede recibir recursos"}

  defp validar_necesidad_activa(_), do: :ok

  defp validar_cantidad_pendiente(%Necesidad{cantidad_pendiente: pendiente}, cantidad)
       when is_integer(cantidad) and cantidad > 0 and pendiente >= cantidad,
       do: :ok

  defp validar_cantidad_pendiente(%Necesidad{cantidad_pendiente: pendiente}, cantidad) do
    {:error,
     "La cantidad solicitada (#{inspect(cantidad)}) supera o no es válida para lo pendiente (#{pendiente})"}
  end

  defp crear_asignaciones(id_necesidad, origenes) do
    Enum.reduce_while(origenes, {:ok, []}, fn {id_recurso, ubicacion, cantidad}, {:ok, acc} ->
      case AsignacionRecurso.nueva_directa(id_necesidad, id_recurso, ubicacion, cantidad) do
        {:ok, asignacion} -> {:cont, {:ok, [asignacion | acc]}}
        {:error, motivo} -> {:halt, {:error, motivo}}
      end
    end)
    |> case do
      {:ok, asignaciones} -> {:ok, Enum.reverse(asignaciones)}
      error -> error
    end
  end

  defp validar_total_asignado(asignaciones, cantidad) do
    total = Enum.reduce(asignaciones, 0, &(&1.cantidad_asignada + &2))

    if total == cantidad,
      do: :ok,
      else: {:error, "La distribución asignada no coincide con la cantidad solicitada"}
  end

  defp validar_texto(valor, campo) when is_binary(valor) do
    if String.trim(valor) == "", do: {:error, "#{campo} es obligatoria"}, else: :ok
  end

  defp validar_texto(_, campo), do: {:error, "#{campo} es obligatoria"}

  defp validar_cantidad(cantidad) when is_integer(cantidad) and cantidad > 0, do: :ok
  defp validar_cantidad(_), do: {:error, "La cantidad debe ser un entero mayor a cero"}

  defp validar_disponibilidad(disponible, cantidad) when disponible >= cantidad, do: :ok

  defp validar_disponibilidad(disponible, cantidad) do
    {:error, "Existencias insuficientes. Solicitado: #{cantidad}, disponible: #{disponible}"}
  end

  defp validar_ubicaciones_distintas(origen, destino) when origen != destino, do: :ok

  defp validar_ubicaciones_distintas(_origen, _destino),
    do: {:error, "El origen y destino deben ser distintos"}
end
