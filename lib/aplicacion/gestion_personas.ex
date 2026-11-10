defmodule Emergencia.Aplicacion.GestionPersonas do
  @moduledoc """
  Coordina el registro, consulta y seguimiento de las
  personas afectadas por una emergencia.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.PoblacionServidor
  alias Emergencia.ActividadesServidor
  alias Emergencia.TerritorioServidor

  # ============================================================
  #  REGISTRO DE PERSONAS
  # ============================================================

  def registrar_persona(sesion, nombre, documento, codigo_zona, estado_persona, opciones \\ [])

  def registrar_persona(%Sesion{} = sesion, nombre, documento, codigo_zona, estado_persona, opciones) do
    with :ok <- Autenticacion.autorizar(sesion, :registrar_persona),
        {:ok, zona} <- TerritorioServidor.buscar_zona(codigo_zona),
        {:ok, persona} <- PoblacionServidor.registrar_persona(nombre, documento, zona.id, estado_persona, opciones) do

         registrar_con_advertencia(
        persona,
        sesion.id_usuario,
        :registro_persona,
        "El usuario #{sesion.nombre_usuario} registró a la persona #{persona.codigo_persona}"
        )

         end
  end

  def registrar_persona(_, _, _, _, _, _), do: {:error, :sesion_invalida}

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

  def cambiar_estado(_, _, _), do: {:error, :sesion_invalida}
  # ============================================================
  # BUSCAR PERSONAS
  # ============================================================

  def buscar_personas(sesion, criterios \\ %{})

  def buscar_personas(%Sesion{} = sesion, criterios) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas),
        {:ok, criterios_resueltos} <- resolver_criterios(criterios),
        {:ok, personas} <- PoblacionServidor.buscar_personas(criterios_resueltos) do
      {:ok, personas}
    end
  end

  def buscar_personas(_, _), do: {:error, :sesion_invalida}

  # ============================================================
#  LISTAR PERSONAS
# ============================================================

  def listar_personas(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_personas),
        {:ok, personas} <- PoblacionServidor.buscar_personas([]) do
      {:ok, personas}
    end
  end

  def listar_personas(_), do: {:error, :sesion_invalida}


  # ============================================================
  # CONSULTAR HISTORIAL
  # ============================================================

  def consultar_historial(%Sesion{} = sesion, identificador) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_historial),
        {:ok, personas} <-
          PoblacionServidor.buscar_personas(
            criterios_identificador(identificador)
          ),
        {:ok, persona} <- obtener_persona_unica(personas),
        {:ok, historial} <-
          PoblacionServidor.consultar_historial_persona(persona.id) do
      {:ok, historial}
    end
  end

  defp criterios_identificador(identificador) do
    if String.starts_with?(String.upcase(identificador), "PER-") do
      [codigo_persona: identificador]
    else
      [documento: identificador]
    end
  end

  defp obtener_persona_unica([persona]), do: {:ok, persona}

  defp obtener_persona_unica([]) do
    {:error, "No se encontró ninguna persona con ese identificador"}
  end

  defp obtener_persona_unica(_personas) do
    {:error, "Se encontraron varias personas. Utilice un identificador más específico"}
  end

  defp resolver_criterios(criterios) do
    case Keyword.pop(criterios, :codigo_zona) do
      {nil, criterios_restantes} ->
        {:ok, criterios_restantes}

      {codigo_zona, criterios_restantes} ->
        with {:ok, zona} <- TerritorioServidor.buscar_zona(codigo_zona) do
          {:ok, Keyword.put(criterios_restantes, :id_zona, zona.id)}
        end
    end
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
