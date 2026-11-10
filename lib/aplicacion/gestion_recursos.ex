defmodule Emergencia.Aplicacion.GestionRecursos do
  @moduledoc """
  Coordina el registro de recursos, inventarios, necesidades, asignaciones,
  transferencias y egresos. Valida permisos, resuelve códigos a ids,
  delega en `RecursosServidor` y audita cada operación.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.Aplicacion.Resolutor
  alias Emergencia.RecursosServidor
  alias Emergencia.ActividadesServidor
  alias Emergencia.TerritorioServidor

  # ------------------------------------------------------------------
  # Necesidades
  # ------------------------------------------------------------------

  def registrar_necesidad(sesion, tipo, cantidad, codigo_zona, prioridad, opciones \\ [])

  def registrar_necesidad(%Sesion{} = sesion, tipo, cantidad, codigo_zona, prioridad, opciones) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_necesidad),
         {:ok, zona} <- TerritorioServidor.buscar_zona(codigo_zona),
         {:ok, necesidad} <-
           RecursosServidor.registrar_necesidad(tipo, cantidad, zona.id, prioridad, opciones) do
      registrar_con_advertencia(
        necesidad,
        sesion.id_usuario,
        :registrar_necesidad,
        "El usuario #{sesion.nombre_usuario} registró una necesidad de tipo #{tipo}"
      )
    end
  end

  def registrar_necesidad(_, _, _, _, _, _), do: {:error, :sesion_invalida}

  def listar_necesidades(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_necesidades) do
      RecursosServidor.listar_necesidades()
    end
  end

  def listar_necesidades(_), do: {:error, :sesion_invalida}

  @doc """
  Lista necesidades aplicando filtros. `filtros` es un keyword list con las
  claves opcionales `:zona` (código o id), `:tipo`, `:prioridad` y `:estado`
  (átomos o textos).
  """
  def listar_necesidades(%Sesion{} = sesion, filtros) when is_list(filtros) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_necesidades),
         {:ok, necesidades} <- RecursosServidor.listar_necesidades() do
      id_zona = if filtros[:zona], do: Resolutor.zona(filtros[:zona])

      {:ok,
       Enum.filter(necesidades, fn n ->
         (is_nil(id_zona) or n.id_zona == id_zona) and
           coincide?(n.tipo, filtros[:tipo]) and
           coincide?(n.prioridad, filtros[:prioridad]) and
           coincide?(n.estado, filtros[:estado])
       end)}
    end
  end

  def listar_necesidades(_, _), do: {:error, :sesion_invalida}

  def listar_necesidades_ordenadas(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_necesidades) do
      RecursosServidor.listar_necesidades_ordenadas()
    end
  end

  def listar_necesidades_ordenadas(_), do: {:error, :sesion_invalida}

  # ------------------------------------------------------------------
  # Recursos e inventarios
  # ------------------------------------------------------------------

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
         id_ub <- Resolutor.ubicacion(ubicacion_cod, tipo_ubicacion),
         id_rec <- Resolutor.recurso(recurso_cod),
         {:ok, inventario} <-
           RecursosServidor.agregar_inventario(id_ub, tipo_ubicacion, id_rec, cantidad) do
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
         id_nec <- Resolutor.necesidad(necesidad_cod),
         {:ok, asignacion} <-
           RecursosServidor.asignar_recurso(id_nec, inventario_id, cantidad, sesion.id_usuario) do
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
         id_rec <- Resolutor.recurso(recurso_cod),
         {id_origen, _tipo_origen} <- Resolutor.ubicacion_transferencia(origen_cod),
         {id_dest, tipo_dest} <- Resolutor.ubicacion_transferencia(destino_cod),
         {:ok, mov} <-
           RecursosServidor.transferir_recurso(id_rec, id_origen, id_dest, tipo_dest, cantidad) do
      registrar_con_advertencia(
        mov,
        sesion.id_usuario,
        :transferir_recurso,
        "El usuario #{sesion.nombre_usuario} transfirió #{cantidad} unidades del recurso #{recurso_cod}"
      )
    end
  end

  def transferir_recurso(_, _, _, _, _), do: {:error, :sesion_invalida}

  def registrar_egreso(%Sesion{} = sesion, recurso_cod, origen_cod, cantidad) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         id_rec <- Resolutor.recurso(recurso_cod),
         {id_origen, _tipo_origen} <- Resolutor.ubicacion_transferencia(origen_cod),
         {:ok, mov} <- RecursosServidor.registrar_egreso(id_rec, id_origen, cantidad) do
      registrar_con_advertencia(
        mov,
        sesion.id_usuario,
        :egreso_recurso,
        "El usuario #{sesion.nombre_usuario} registró un egreso de #{cantidad} unidades del recurso #{recurso_cod}"
      )
    end
  end

  def registrar_egreso(_, _, _, _), do: {:error, :sesion_invalida}

  def listar_recursos(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos) do
      RecursosServidor.listar_recursos()
    end
  end

  def listar_recursos(_), do: {:error, :sesion_invalida}

  def listar_inventarios(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos) do
      RecursosServidor.listar_inventarios()
    end
  end

  def listar_inventarios(_), do: {:error, :sesion_invalida}

  def calcular_stock_global(%Sesion{} = sesion, recurso_cod) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos) do
      RecursosServidor.calcular_stock_global(Resolutor.recurso(recurso_cod))
    end
  end

  def calcular_stock_global(_, _), do: {:error, :sesion_invalida}

  # ------------------------------------------------------------------
  # Auxiliares
  # ------------------------------------------------------------------

  defp coincide?(_valor, nil), do: true
  defp coincide?(valor, esperado), do: to_string(valor) == to_string(esperado)

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(id_responsable, accion, descripcion) do
      {:ok, _actividad} -> {:ok, resultado}
      {:error, motivo} -> {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end

