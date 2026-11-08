defmodule Emergencia.Aplicacion.GestionFamilias do
  @moduledoc """
  Coordina la gestión de familias y la asignación
  de personas a ellas.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.PoblacionServidor
  alias Emergencia.ActividadesServidor


 @doc """
  Registra una nueva familia.
  """
  def asignar_familia(%Sesion{} = sesion, id_persona, id_familia) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_familia),
          {:ok, persona} <- PoblacionServidor.asignar_familia(id_persona, id_familia) do

        registrar_con_advertencia(
        persona,
        sesion.id_usuario,
        :asignacion_familia,
        "El usuario #{sesion.nombre_usuario} asignó la persona " <>
          "#{persona.codigo_persona} a una familia"
      )
      end
  end

  def asignar_familia(_, _, _) do
    {:error, :sesion_invalida}
  end

   @doc """
  Busca una familia mediante su UUID o código.
  """
  def buscar_familia(%Sesion{} = sesion, id_o_codigo) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_familias) do
      PoblacionServidor.buscar_familia(id_o_codigo)
    end
  end

  def buscar_familia(_, _), do: {:error, :sesion_invalida}

  @doc """
  Lista todas las familias registradas.
  """
  def listar_familias(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_familias) do
      PoblacionServidor.listar_familias()
    end
  end

  def listar_familias(_), do: {:error, :sesion_invalida}

    @doc """
  Consulta los integrantes de una familia mediante su UUID o código.
  """
  def consultar_integrantes(%Sesion{} = sesion, id_o_codigo_familia) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_familias) do
      PoblacionServidor.consultar_integrantes(id_o_codigo_familia)
    end
  end

  def consultar_integrantes(_, _), do: {:error, :sesion_invalida}

   @doc """
  Asigna una persona a una familia.

  Recibe el UUID de la persona y el UUID o código de la familia.
  """
  def asignar_persona(%Sesion{} = sesion, id_persona, id_o_codigo_familia) do
    with :ok <- Autenticacion.autorizar(sesion, :asignar_familia),
         {:ok, familia} <- PoblacionServidor.buscar_familia(id_o_codigo_familia),
         {:ok, persona} <- PoblacionServidor.asignar_familia(
           id_persona,
           familia.id
         ) do
      registrar_con_advertencia(
        persona,
        sesion.id_usuario,
        :asignacion_familia,
        "El usuario #{sesion.nombre_usuario} asignó una persona a la familia #{familia.codigo_familia}"
      )
    end
  end

  def asignar_persona(_, _, _), do: {:error, :sesion_invalida}

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
