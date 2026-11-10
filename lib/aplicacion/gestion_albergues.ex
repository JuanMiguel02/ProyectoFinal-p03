defmodule Emergencia.Aplicacion.GestionAlbergues do
  @moduledoc """
  Coordina el registro y la gestión de albergues,
  incluyendo ingresos, salidas y consultas de ocupación.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.Aplicacion.Resolutor
  alias Emergencia.PoblacionServidor
  alias Emergencia.ActividadesServidor
  alias Emergencia.TerritorioServidor

  @doc """
  Registra un nuevo albergue.
  """
  def registrar_albergue(%Sesion{} = sesion, nombre, codigo_zona, capacidad_maxima) do
    with :ok <- Autenticacion.autorizar(sesion, :registrar_albergue),
         {:ok, zona} <- TerritorioServidor.buscar_zona(codigo_zona),
         {:ok, albergue} <- PoblacionServidor.registrar_albergue(nombre, zona.id , capacidad_maxima) do

       registrar_con_advertencia(
        albergue,
        sesion.id_usuario,
        :registro_albergue,
        "El usuario #{sesion.nombre_usuario} registró el albergue #{albergue.codigo}"
      )
    end
  end

  def registrar_albergue(_, _, _, _), do: {:error, :sesion_invalida}

  @doc """
  Ingresa una persona a un albergue.
  """
  def ingresar_persona(%Sesion{} = sesion, id_persona, id_albergue) do
    with :ok <- Autenticacion.autorizar(sesion, :ingreso_albergue),
         {:ok, registro} <- PoblacionServidor.ingresar_persona(Resolutor.persona(id_persona), Resolutor.albergue(id_albergue)) do

      registrar_con_advertencia(
        registro,
        sesion.id_usuario,
        :ingreso_albergue,
        "El usuario #{sesion.nombre_usuario} registró el ingreso de una persona a un albergue"
      )
    end
  end

  def ingresar_persona(_, _, _), do: {:error, :sesion_invalida}

   @doc """
  Registra la salida de una persona de su albergue.
  """
  def registrar_salida(sesion, id_persona, nuevo_estado_persona \\ :localizada)

  def registrar_salida(%Sesion{} = sesion, id_persona, nuevo_estado_persona) do
    with :ok <- Autenticacion.autorizar(sesion, :salida_albergue),
         {:ok, registro} <- PoblacionServidor.registrar_salida(Resolutor.persona(id_persona), nuevo_estado_persona) do

       registrar_con_advertencia(
        registro,
        sesion.id_usuario,
        :salida_albergue,
        "El usuario #{sesion.nombre_usuario} registró la salida de una persona de un albergue"
      )
    end
  end

  def registrar_salida(_, _, _), do: {:error, :sesion_invalida}

   @doc """
  Consulta los cupos disponibles de un albergue.
  """
  def consultar_cupos(%Sesion{} = sesion, id_albergue) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_albergues) do
      PoblacionServidor.consultar_cupos(Resolutor.albergue(id_albergue))
    end
  end

  def consultar_cupos(_, _), do: {:error, :sesion_invalida}

  @doc """
  Consulta la ocupación de un albergue.
  """
  def consultar_ocupacion(%Sesion{} = sesion, id_albergue) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_albergues) do
      PoblacionServidor.consultar_ocupacion(Resolutor.albergue(id_albergue))
    end
  end

  def consultar_ocupacion(_, _), do: {:error, :sesion_invalida}

  @doc """
  Genera un reporte de ocupación de todos los albergues.
  """
  def reporte_ocupacion(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_albergues) do
      PoblacionServidor.reporte_ocupacion()
    end
  end

  def reporte_ocupacion(_), do: {:error, :sesion_invalida}

  def listar_albergues(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_albergues),
        {:ok, albergues} <- PoblacionServidor.listar_albergues() do
      {:ok, albergues}
    end
  end

  def listar_albergues(_), do: {:error, :sesion_invalida}

  # ------------------------------------------------------------------
  # Auditoría
  # ------------------------------------------------------------------

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(
           id_responsable,
           accion,
           descripcion
         ) do
      {:ok, _actividad} ->
        {:ok, resultado}

      {:error, motivo} ->
        {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end

end
