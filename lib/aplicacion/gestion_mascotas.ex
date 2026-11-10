defmodule Emergencia.Aplicacion.GestionMascotas do
  @moduledoc """
  Coordina el registro de reportes de mascotas, búsqueda de coincidencias y resolución.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.MascotasServidor
  alias Emergencia.ActividadesServidor
  alias Emergencia.TerritorioServidor

  def registrar_reporte(sesion, tipo, especie, color, tamano, zona_cod, contacto, opciones \\ [])
  def registrar_reporte(%Sesion{} = sesion, tipo, especie, color, tamano, zona_cod, _contacto, opciones) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_reporte_mascota),
         {:ok, zona} <- TerritorioServidor.buscar_zona(zona_cod),
         {:ok, reporte} <- MascotasServidor.registrar_reporte(tipo, especie, color, tamano, zona.id, sesion.id_usuario, opciones) do
      registrar_con_advertencia(
        reporte,
        sesion.id_usuario,
        :registrar_reporte_mascota,
        "El usuario #{sesion.nombre_usuario} registró reporte de mascota #{tipo}"
      )
    end
  end

  def registrar_reporte(_, _, _, _, _, _, _, _), do: {:error, :sesion_invalida}

  def listar_reportes(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes) do
      MascotasServidor.listar_reportes()
    end
  end

  def listar_reportes(_), do: {:error, :sesion_invalida}

  def listar_coincidencias(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes) do
      MascotasServidor.listar_coincidencias()
    end
  end

  def listar_coincidencias(_), do: {:error, :sesion_invalida}

  def confirmar_coincidencia(%Sesion{} = sesion, id_coincidencia) do
    with :ok <- Autenticacion.autorizar(sesion, :confirmar_coincidencia),
         {:ok, coincidencia} <- MascotasServidor.confirmar_coincidencia(id_coincidencia, sesion.id_usuario) do
      registrar_con_advertencia(
        coincidencia,
        sesion.id_usuario,
        :confirmar_coincidencia_mascota,
        "El usuario #{sesion.nombre_usuario} confirmó una coincidencia de mascota"
      )
    end
  end

  def confirmar_coincidencia(_, _), do: {:error, :sesion_invalida}

  def buscar_coincidencias(%Sesion{} = sesion, id_reporte) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes) do
      MascotasServidor.buscar_coincidencias(id_reporte)
    end
  end

  def buscar_coincidencias(_, _), do: {:error, :sesion_invalida}

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(id_responsable, accion, descripcion) do
      {:ok, _act} -> {:ok, resultado}
      {:error, motivo} -> {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end
