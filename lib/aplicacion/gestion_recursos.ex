defmodule Emergencia.Aplicacion.GestionRecursos do
  @moduledoc """
  Coordina el registro de recursos, existencias, necesidades, asignaciones,
  transferencias. Valida permisos, resuelve códigos a ids,
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

  def registrar_necesidad(
        sesion,
        tipo,
        cantidad,
        codigo_zona,
        prioridad,
        codigo_destinatario,
        opciones \\ []
      )

  def registrar_necesidad(
        %Sesion{} = sesion,
        tipo,
        cantidad,
        codigo_zona,
        prioridad,
        codigo_destinatario,
        opciones
      ) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_necesidad),
         {:ok, zona} <- TerritorioServidor.buscar_zona(codigo_zona),
         {:ok, destinatario} <- Resolutor.destinatario_necesidad(codigo_destinatario),
         {:ok, necesidad} <-
           RecursosServidor.registrar_necesidad(
             tipo,
             cantidad,
             zona.id,
             prioridad,
             Keyword.merge(opciones,
               id_responsable: sesion.id_usuario,
               id_destinatario: destinatario.id,
               entidad_asociada: destinatario.entidad_asociada
             )
           ) do
      registrar_con_advertencia(
        necesidad,
        sesion.id_usuario,
        :registrar_necesidad,
        "El usuario #{sesion.nombre_usuario} registró una necesidad de tipo #{tipo}"
      )
    end
  end

  def registrar_necesidad(_, _, _, _, _, _, _), do: {:error, :sesion_invalida}

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
  # Recursos y existencias directas por ubicación
  # ------------------------------------------------------------------

 def registrar_recurso(
      %Sesion{} = sesion,
      nombre,
      categoria,
      cantidad,
      unidad_medida,
      ubicacion
    ) do
  with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
       {:ok, ubicacion} <- Resolutor.ubicacion_recurso(ubicacion),
       {:ok, recurso} <-
         RecursosServidor.registrar_recurso(
           nombre,
           categoria,
           cantidad,
           unidad_medida,
           ubicacion
         ) do
    registrar_con_advertencia(
      recurso,
      sesion.id_usuario,
      :registrar_recurso,
      "El usuario #{sesion.nombre_usuario} registró #{cantidad} unidades de #{recurso.codigo} (categoría: #{recurso.categoria}) en #{ubicacion}"
    )
  end
end

  def registrar_recurso(_, _, _, _, _), do: {:error, :sesion_invalida}

  def asignar_recurso(%Sesion{} = sesion, necesidad_cod, recurso_cod, cantidad) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         id_nec <- Resolutor.necesidad(necesidad_cod),
         codigo_recurso <- Resolutor.codigo_recurso(recurso_cod),
         {:ok, asignacion} <-
           RecursosServidor.asignar_recurso_directo(
             id_nec,
             codigo_recurso,
             cantidad,
             sesion.id_usuario
           ) do
      registrar_con_advertencia(
        asignacion,
        sesion.id_usuario,
        :asignar_recurso,
        "El usuario #{sesion.nombre_usuario} asignó el recurso #{recurso_cod} a la necesidad #{necesidad_cod}"
      )
    end
  end

  def asignar_recurso(_, _, _, _), do: {:error, :sesion_invalida}

  def transferir_recurso(%Sesion{} = sesion, recurso_cod, origen, destino, cantidad) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_recursos),
         codigo <- Resolutor.codigo_recurso(recurso_cod),
         {:ok, origen} <- Resolutor.ubicacion_recurso(origen),
         {:ok, destino} <- Resolutor.ubicacion_recurso(destino),
         {:ok, mov} <-
           RecursosServidor.transferir_recurso(codigo, origen, destino, cantidad) do
      registrar_con_advertencia(
        mov,
        sesion.id_usuario,
        :transferir_recurso,
        "El usuario #{sesion.nombre_usuario} transfirió #{cantidad} unidades del recurso #{recurso_cod}"
      )
    end
  end

  def transferir_recurso(_, _, _, _, _), do: {:error, :sesion_invalida}

  def listar_recursos(sesion, ubicacion \\ nil)

  def listar_recursos(%Sesion{} = sesion, ubicacion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos) do
      filtros = if is_nil(ubicacion), do: %{}, else: %{ubicacion: ubicacion}
      RecursosServidor.listar_recursos(filtros)
    end
  end

  def listar_recursos(_, _), do: {:error, :sesion_invalida}

  def listar_todos_recursos(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos) do
      RecursosServidor.listar_todos_recursos()
    end
  end

  def listar_todos_recursos(_), do: {:error, :sesion_invalida}

  def calcular_stock_global(%Sesion{} = sesion, recurso_cod) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos) do
      codigo = Resolutor.codigo_recurso(recurso_cod)
      RecursosServidor.calcular_stock_global(codigo)
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
