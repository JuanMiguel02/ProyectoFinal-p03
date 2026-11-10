defmodule Emergencia.Aplicacion.GestionResumen do
  @moduledoc """
  Construye el resumen global del sistema combinando información de los
  distintos servidores. La presentación solo recibe un mapa de totales.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.{
    TerritorioServidor,
    RecursosServidor,
    PoblacionServidor,
    MensajesServidor,
    MascotasServidor
  }

  def resumen_global(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_zonas) do
      necesidades = lista(RecursosServidor.listar_necesidades())
      personas = lista(PoblacionServidor.buscar_personas([]))
      reportes = lista(MascotasServidor.listar_reportes())
      inventarios = lista(RecursosServidor.listar_inventarios())

      {:ok,
       %{
         zonas: length(lista(TerritorioServidor.listar_zonas())),
         necesidades_totales: length(necesidades),
         necesidades_pendientes: Enum.count(necesidades, &(&1.estado == :pendiente)),
         albergues: length(lista(PoblacionServidor.listar_albergues())),
         personas_registradas: length(personas),
         personas_localizadas: Enum.count(personas, &(&1.estado == :localizada)),
         mensajes: length(lista(MensajesServidor.listar())),
         reportes_mascotas: length(reportes),
         reportes_mascotas_activos: Enum.count(reportes, &(&1.estado == :activa)),
         unidades_disponibles: Enum.reduce(inventarios, 0, &(&1.cantidad_disponible + &2))
       }}
    end
  end

  def resumen_global(_), do: {:error, :sesion_invalida}

  @doc "Inventarios con existencias por debajo de `umbral` unidades."
  def recursos_criticos(sesion, umbral \\ 10)

  def recursos_criticos(%Sesion{} = sesion, umbral) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos),
         {:ok, inventarios} <- RecursosServidor.listar_inventarios() do
      {:ok, Enum.filter(inventarios, &(&1.cantidad_disponible < umbral))}
    end
  end

  def recursos_criticos(_, _), do: {:error, :sesion_invalida}

  defp lista({:ok, l}) when is_list(l), do: l
  defp lista(_), do: []
end
