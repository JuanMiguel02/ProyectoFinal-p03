defmodule Emergencia.Aplicacion.GestionRecursos do
  @moduledoc """
  Coordina el registro de recursos, inventarios, necesidades, asignaciones y transferencias.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.RecursosServidor
  alias Emergencia.ActividadesServidor
  alias Emergencia.TerritorioServidor
  alias Emergencia.PoblacionServidor

  def registrar_necesidad(sesion, tipo, cantidad, codigo_zona, prioridad, opciones \\ [])
  def registrar_necesidad(%Sesion{} = sesion, tipo, cantidad, codigo_zona, prioridad, opciones) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_necesidad),
         {:ok, zona} <- TerritorioServidor.buscar_zona(codigo_zona),
         {:ok, necesidad} <- RecursosServidor.registrar_necesidad(tipo, cantidad, zona.id, prioridad, opciones) do
      registrar_con_advertencia(
        necesidad,
        sesion.id_usuario,
        :registrar_necesidad,
        "El usuario #{sesion.nombre_usuario} registró una necesidad de tipo #{tipo}"
      )
    end
  end

  def registrar_necesidad(_, _, _, _, _, _), do: {:error, :sesion_invalida}

  def registrar_recurso(%Sesion{} = sesion, nombre, categoria, unidad_medida) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         {:ok, recurso} <- RecursosServidor.registrar_recurso(nombre, categoria, unidad_medida) do
      registrar_con_advertencia(
        recurso,
        sesion.id_usuario,
        :registrar_recurso,
        "El usuario #{sesion.nombre_usuario} registró el recurso #{nombre}"
      )
    end
  end

  def registrar_recurso(_, _, _, _), do: {:error, :sesion_invalida}

  def agregar_inventario(%Sesion{} = sesion, ubicacion_cod, tipo_ubicacion, recurso_cod, cantidad) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         id_ub <- resolver_id_ubicacion(ubicacion_cod, tipo_ubicacion),
         id_rec <- resolver_id_recurso(recurso_cod),
         {:ok, inventario} <- RecursosServidor.agregar_inventario(id_ub, tipo_ubicacion, id_rec, cantidad) do
      registrar_con_advertencia(
        inventario,
        sesion.id_usuario,
        :agregar_inventario,
        "El usuario #{sesion.nombre_usuario} agregó inventario del recurso #{recurso_cod}"
      )
    end
  end

  def agregar_inventario(_, _, _, _, _), do: {:error, :sesion_invalida}

  def asignar_recurso(%Sesion{} = sesion, necesidad_cod, inventario_id, cantidad) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         id_nec <- resolver_id_necesidad(necesidad_cod),
         {:ok, asignacion} <- RecursosServidor.asignar_recurso(id_nec, inventario_id, cantidad, sesion.id_usuario) do
      registrar_con_advertencia(
        asignacion,
        sesion.id_usuario,
        :asignar_recurso,
        "El usuario #{sesion.nombre_usuario} asignó recurso a la necesidad #{necesidad_cod}"
      )
    end
  end

  def asignar_recurso(_, _, _, _), do: {:error, :sesion_invalida}

  def transferir_recurso(%Sesion{} = sesion, recurso_cod, origen_cod, destino_cod, cantidad) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         id_rec <- resolver_id_recurso(recurso_cod),
         {id_origen, _tipo_orig} <- resolver_ubicacion_transferencia(origen_cod),
         {id_dest, tipo_dest} <- resolver_ubicacion_transferencia(destino_cod),
         {:ok, mov} <- RecursosServidor.transferir_recurso(id_rec, id_origen, id_dest, tipo_dest, cantidad) do
      registrar_con_advertencia(
        mov,
        sesion.id_usuario,
        :transferir_recurso,
        "El usuario #{sesion.nombre_usuario} transfirió #{cantidad} unidades del recurso #{recurso_cod}"
      )
    end
  end

  def transferir_recurso(_, _, _, _, _), do: {:error, :sesion_invalida}

  def listar_recursos(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos) do
      RecursosServidor.listar_recursos()
    end
  end

  def listar_recursos(_), do: {:error, :sesion_invalida}

  def listar_inventarios(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos) do
      RecursosServidor.listar_inventarios()
    end
  end

  def listar_inventarios(_), do: {:error, :sesion_invalida}

  def listar_necesidades(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas) do
      RecursosServidor.listar_necesidades()
    end
  end

  def listar_necesidades(_), do: {:error, :sesion_invalida}

  def listar_necesidades_ordenadas(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas) do
      RecursosServidor.listar_necesidades_ordenadas()
    end
  end

  def listar_necesidades_ordenadas(_), do: {:error, :sesion_invalida}

  def calcular_stock_global(%Sesion{} = sesion, recurso_cod) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         id_rec <- resolver_id_recurso(recurso_cod) do
      RecursosServidor.calcular_stock_global(id_rec)
    end
  end

  def calcular_stock_global(_, _), do: {:error, :sesion_invalida}

  # Resolvidores internos auxiliares
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
    centros = case TerritorioServidor.listar_centros_acopio() do {:ok, l} -> l; _ -> [] end
    albergues = case PoblacionServidor.listar_albergues() do {:ok, l} -> l; _ -> [] end
    centro = Enum.find(centros, fn c -> c.id == entrada or c.codigo_centro_acopio == entrada end)
    albergue = Enum.find(albergues, fn a -> a.id == entrada or a.codigo == entrada end)
    cond do
      centro -> {centro.id, :centro_acopio}
      albergue -> {albergue.id, :albergue}
      true ->
        id_z = resolver_id_zona(entrada)
        if id_z != entrada, do: {id_z, :centro_acopio}, else: {entrada, :albergue}
    end
  end

  defp find_by_code_or_id(lista, entrada, code_fun) when is_list(lista) do
    match = Enum.find(lista, fn ent -> ent.id == entrada or code_fun.(ent) == entrada end)
    if match, do: match.id, else: entrada
  end

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(id_responsable, accion, descripcion) do
      {:ok, _actividad} -> {:ok, resultado}
      {:error, motivo} -> {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end
