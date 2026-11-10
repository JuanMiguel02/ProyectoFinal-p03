defmodule Emergencia.EstadoRecursos do
  @moduledoc false
  defstruct recursos: %{}, inventarios: %{}, necesidades: %{}, movimientos_recursos: %{}, asignaciones_recursos: %{}
end

defmodule Emergencia.RecursosServidor do
  use GenServer
  alias Emergencia.EstadoRecursos
  alias Emergencia.GestorDatos
  alias Emergencia.Servicios.ServicioRecursos

  # ============================================================================
  # API pública
  # ============================================================================


  def listar_recursos, do: GenServer.call(__MODULE__, :listar_recursos)
  def listar_necesidades, do: GenServer.call(__MODULE__, :listar_necesidades)
  def listar_inventarios, do: GenServer.call(__MODULE__, :listar_inventarios)
  def listar_centros_acopio, do: GenServer.call(__MODULE__, :listar_centros_acopio)

  def start_link(opciones \\ []) do
    GenServer.start_link(__MODULE__, opciones, name: __MODULE__)
  end

  def registrar_necesidad(tipo, cantidad, id_zona, prioridad, opciones \\ []) do
    GenServer.call(__MODULE__, {:registrar_necesidad, tipo, cantidad, id_zona, prioridad, opciones})
  end

  def registrar_recurso(nombre, categoria, unidad_medida) do
    GenServer.call(__MODULE__, {:registrar_recurso, nombre, categoria, unidad_medida})
  end

  def agregar_inventario(id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
    GenServer.call(__MODULE__, {:agregar_inventario, id_ubicacion, tipo_ubicacion, id_recurso, cantidad})
  end

  def asignar_recurso(id_necesidad, id_inventario, cantidad, id_usuario \\ "SISTEMA") do
    GenServer.call(__MODULE__, {:asignar_recurso, id_necesidad, id_inventario, cantidad, id_usuario})
  end

  def transferir_recurso(id_recurso, id_origen, id_destino, tipo_destino, cantidad) do
    GenServer.call(__MODULE__, {:transferir_recurso, id_recurso, id_origen, id_destino, tipo_destino, cantidad})
  end

  def listar_necesidades_ordenadas, do: GenServer.call(__MODULE__, :listar_necesidades_ordenadas)

  def calcular_stock_global(id_recurso), do: GenServer.call(__MODULE__, {:calcular_stock_global, id_recurso})

  def registrar_egreso(id_recurso, id_origen, cantidad) do
    GenServer.call(__MODULE__, {:registrar_egreso, id_recurso, id_origen, cantidad})
  end

  # ============================================================================
  # Callbacks de GenServer
  # ============================================================================
  @impl true
  def init(_opciones) do
    case GestorDatos.cargar_dominio(:recursos) do
      {:ok, datos} ->
        estado = %EstadoRecursos{
          recursos: Map.get(datos, :recursos, %{}),
          inventarios: Map.get(datos, :inventarios, %{}),
          necesidades: Map.get(datos, :necesidades, %{}),
          movimientos_recursos: Map.get(datos, :movimientos_recursos, %{}),
          asignaciones_recursos: Map.get(datos, :asignaciones_recursos, %{})
        }
        {:ok, estado}

      {:error, motivo} ->
        {:stop, {:error_cargando_recursos, motivo}}
    end
  end

  @impl true
  def handle_call({:registrar_necesidad, tipo, cantidad, id_zona, prioridad, opciones}, _from, estado) do
    case ServicioRecursos.registrar_necesidad(estado, tipo, cantidad, id_zona, prioridad, opciones) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:registrar_recurso, nombre, categoria, unidad_medida}, _from, estado) do
    case ServicioRecursos.registrar_recurso(estado, nombre, categoria, unidad_medida) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:agregar_inventario, id_ubicacion, tipo_ubicacion, id_recurso, cantidad}, _from, estado) do
    case ServicioRecursos.agregar_inventario(estado, id_ubicacion, tipo_ubicacion, id_recurso, cantidad) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:asignar_recurso, id_necesidad, id_inventario, cantidad, id_usuario}, _from, estado) do
    case ServicioRecursos.asignar_recurso(estado, id_necesidad, id_inventario, cantidad, id_usuario) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  @impl true
  def handle_call({:transferir_recurso, id_recurso, id_origen, id_destino, tipo_destino, cantidad}, _from, estado) do
    case ServicioRecursos.transferir_recurso(estado, id_recurso, id_origen, id_destino, tipo_destino, cantidad) do
      {:ok, resultado, nuevo_estado} ->
        procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} ->
        {:reply, {:error, motivo}, estado}
    end
  end

  def handle_call(:listar_recursos, _from, estado), do: {:reply, {:ok, Map.values(estado.recursos)}, estado}
  def handle_call(:listar_necesidades, _from, estado), do: {:reply, {:ok, Map.values(estado.necesidades)}, estado}
  def handle_call(:listar_inventarios, _from, estado), do: {:reply, {:ok, Map.values(estado.inventarios)}, estado}
  def handle_call(:listar_centros_acopio, _from, estado), do: {:reply, {:ok, Map.values(estado.centros_acopio)}, estado}

  @impl true
  def handle_call(:listar_necesidades_ordenadas, _from, estado) do
    {:reply, ServicioRecursos.listar_necesidades_ordenadas(estado), estado}
  end

  @impl true
  def handle_call({:calcular_stock_global, id_recurso}, _from, estado) do
    {:reply, ServicioRecursos.calcular_stock_global(estado, id_recurso), estado}
  end

  @impl true
  def handle_call({:registrar_egreso, id_recurso, id_origen, cantidad}, _from, estado) do
    case ServicioRecursos.registrar_egreso(estado, id_recurso, id_origen, cantidad) do
      {:ok, resultado, nuevo_estado} -> procesar_persistencia(resultado, nuevo_estado, estado)
      {:error, motivo} -> {:reply, {:error, motivo}, estado}
    end
  end

  # ============================================================================
  # Persistencia
  # ============================================================================
  defp procesar_persistencia(resultado, nuevo_estado, estado_anterior) do
    case persistir(nuevo_estado) do
      :ok -> {:reply, {:ok, resultado}, nuevo_estado}
      {:error, motivo} -> {:reply, {:error, {:error_persistencia, motivo}}, estado_anterior}
    end
  end

  defp persistir(%EstadoRecursos{} = estado) do
    GestorDatos.guardar_dominio(
      %{
        recursos: estado.recursos,
        inventarios: estado.inventarios,
        necesidades: estado.necesidades,
        movimientos_recursos: estado.movimientos_recursos,
        asignaciones_recursos: estado.asignaciones_recursos
      },
      :recursos
    )
  end
end
