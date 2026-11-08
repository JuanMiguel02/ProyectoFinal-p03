defmodule Emergencia.Aplicacion.GestionPersonas do
  @moduledoc """
  Coordina el registro, consulta y seguimiento de las
  personas afectadas por una emergencia.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.PoblacionServidor
  alias Emergencia.ActividadesServidor

  # ============================================================
  #  REGISTRO DE PERSONAS
  # ============================================================

  def registrar_persona(%Sesion{} = sesion, nombre, documento, id_zona, estado_persona, opciones \\ []) do
    with :ok <- Autenticacion.autorizar(sesion, :registrar_persona),
         {:ok, persona} <- PoblacionServidor.registrar_persona(nombre, documento, id_zona, estado_persona, opciones) do

         registrar_con_advertencia(
        persona,
        sesion.id_usuario,
        :registro_persona,
        "El usuario #{sesion.nombre_usuario} registró a la persona #{persona.codigo_persona}"
        )

         end
  end

  def registrar_persona(_, _, _, _, _, _) do
    {:error, :sesion_invalida}
  end

  # ============================================================
  #  CAMBIAR ESTADO DE PERSONA
  # ============================================================
  def cambiar_estado(%Sesion{} = sesion, id_persona, nuevo_estado) do
    with :ok <- Autenticacion.autorizar(sesion, :cambiar_estado_persona),
    {:ok, persona} <- PoblacionServidor.cambiar_estado_persona(id_persona, nuevo_estado) do

       registrar_con_advertencia(
        persona,
        sesion.id_usuario,
        :cambio_estado_persona,
        "El usuario #{sesion.nombre_usuario} cambió el estado de " <>
          "#{persona.codigo_persona} a #{nuevo_estado}"
      )
    end
  end

  # ============================================================
  # BUSCAR PERSONAS
  # ============================================================

  def buscar_personas(%Sesion{} = sesion, criterios \\ %{}) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas) do
      PoblacionServidor.buscar_personas(criterios)
    end
  end

  def buscar_personas(_, _) do
    {:error, :sesion_invalida}
  end

  # ============================================================
  # CONSULTAR HISTORIAL
  # ============================================================

  def consultar_historial(%Sesion{} = sesion, documento_o_id) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas) do
      PoblacionServidor.consultar_historial_persona(documento_o_id)
    end
  end

  def consultar_historial(_, _) do
    {:error, :sesion_invalida}
  end

  # ============================================================
  #  AUDITORÍA
  # ============================================================

  defp registrar_con_advertencia(
         resultado,
         id_responsable,
         accion,
         descripcion
       ) do

    case ActividadesServidor.registrar(
           id_responsable,
           accion,
           descripcion
         ) do

      {:ok, _actividad} ->
        {:ok, resultado}

      {:error, motivo} ->
        {:ok, resultado,
         {:advertencia, {:error_auditoria, motivo}}}
    end
  end

end
