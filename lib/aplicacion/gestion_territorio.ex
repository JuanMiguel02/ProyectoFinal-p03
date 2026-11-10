defmodule Emergencia.Aplicacion.GestionTerritorio do
  @moduledoc """
  Coordina el registro y la consulta de zonas, sectores y centros de acopio.
  Valida permisos, delega en `TerritorioServidor` y audita cada operación.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.Aplicacion.Resolutor
  alias Emergencia.TerritorioServidor
  alias Emergencia.ActividadesServidor

  # ------------------------------------------------------------------
  # Registro
  # ------------------------------------------------------------------

  def registrar_zona(%Sesion{} = sesion, nombre, nivel, personas_estimadas) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_zona),
         {:ok, zona} <-
           TerritorioServidor.registrar_zona(nombre, nivel, personas_estimadas, sesion.id_usuario) do
      registrar_con_advertencia(
        zona,
        sesion.id_usuario,
        :registrar_zona,
        "El usuario #{sesion.nombre_usuario} registró la zona #{nombre}"
      )
    end
  end

  def registrar_zona(_, _, _, _), do: {:error, :sesion_invalida}

  def registrar_sector(%Sesion{} = sesion, zona, nombre, nivel, personas_afectadas) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_sector),
         {:ok, sector} <-
           TerritorioServidor.registrar_sector(
             Resolutor.zona(zona),
             nombre,
             nivel,
             personas_afectadas,
             sesion.id_usuario
           ) do
      registrar_con_advertencia(
        sector,
        sesion.id_usuario,
        :registrar_sector,
        "El usuario #{sesion.nombre_usuario} registró el sector #{nombre}"
      )
    end
  end

  def registrar_sector(_, _, _, _, _), do: {:error, :sesion_invalida}

  def registrar_centro_acopio(%Sesion{} = sesion, nombre, direccion, capacidad, zona) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_zona),
         {:ok, centro} <-
           TerritorioServidor.registrar_centro_acopio(
             nombre,
             direccion,
             capacidad,
             Resolutor.zona(zona)
           ) do
      registrar_con_advertencia(
        centro,
        sesion.id_usuario,
        :registrar_centro_acopio,
        "El usuario #{sesion.nombre_usuario} registró el centro de acopio #{nombre}"
      )
    end
  end

  def registrar_centro_acopio(_, _, _, _, _), do: {:error, :sesion_invalida}

  def registrar_punto_atencion(sesion, sector, nombre, tipo, ubicacion, descripcion \\ nil)

  def registrar_punto_atencion(%Sesion{} = sesion, sector, nombre, tipo, ubicacion, descripcion) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_sector),
         {:ok, punto} <-
           TerritorioServidor.registrar_punto_atencion(
             sector,
             nombre,
             tipo,
             ubicacion,
             descripcion
           ) do
      registrar_con_advertencia(
        punto,
        sesion.id_usuario,
        :registrar_punto_atencion,
        "El usuario #{sesion.nombre_usuario} registró el punto de atención #{nombre}"
      )
    end
  end

  def registrar_punto_atencion(_, _, _, _, _, _), do: {:error, :sesion_invalida}

  # ------------------------------------------------------------------
  # Consultas
  # ------------------------------------------------------------------

  def listar_zonas(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_zonas) do
      TerritorioServidor.listar_zonas()
    end
  end

  def listar_zonas(_), do: {:error, :sesion_invalida}

  def listar_sectores(%Sesion{} = sesion, zona) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_zonas) do
      TerritorioServidor.listar_sectores(Resolutor.zona(zona))
    end
  end

  def listar_sectores(_, _), do: {:error, :sesion_invalida}

  def listar_centros_acopio(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_zonas) do
      TerritorioServidor.listar_centros_acopio()
    end
  end

  def listar_centros_acopio(_), do: {:error, :sesion_invalida}

  @doc """
  Estadísticas acumuladas de una zona y sus sectores. Devuelve
  `{:ok, %{estadisticas: stats, sectores: sectores}}`.
  """
  def estadisticas_zona(%Sesion{} = sesion, zona) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_zonas) do
      id_zona = Resolutor.zona(zona)

      with {:ok, stats} <- TerritorioServidor.estadisticas_zona(id_zona) do
        sectores =
          case TerritorioServidor.listar_sectores(id_zona) do
            {:ok, lista} -> lista
            _ -> []
          end

        {:ok, %{estadisticas: stats, sectores: sectores}}
      end
    end
  end

  def estadisticas_zona(_, _), do: {:error, :sesion_invalida}

  # ------------------------------------------------------------------
  # Auditoría
  # ------------------------------------------------------------------

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(id_responsable, accion, descripcion) do
      {:ok, _actividad} -> {:ok, resultado}
      {:error, motivo} -> {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end
