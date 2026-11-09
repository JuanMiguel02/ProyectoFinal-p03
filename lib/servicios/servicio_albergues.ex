defmodule Emergencia.Servicios.ServicioAlbergue do
  alias Emergencia.Persona
  alias Emergencia.Albergue
  alias Emergencia.RegistroAlbergue
  alias Emergencia.GeneradorID

  @moduledoc """
  Gestiona los albergues, sus ocupaciones y los movimientos
  de ingreso y salida de personas.
  """

  # ===========================================================================
  # Registrar albergue
  # ===========================================================================

  def registrar(estado, nombre, id_zona, capacidad_maxima) do
    codigo_albergue = GeneradorID.generar("ALB", estado.albergues, & &1.codigo)

    with :ok <- validar_codigo_unico(estado.albergues, codigo_albergue),
         {:ok, albergue} <- Albergue.nuevo(codigo_albergue, nombre, id_zona, capacidad_maxima) do
      nuevos_albergues = Map.put(estado.albergues, albergue.id, albergue)

      nuevo_estado = %{estado | albergues: nuevos_albergues}

      {:ok, albergue, nuevo_estado}
    end
  end

  # ===========================================================================
  # Ingresar persona
  # ===========================================================================

  def ingresar_persona(estado, id_persona, id_albergue, opciones \\ []) do
    with {:ok, persona} <- obtener_persona(estado, id_persona),
         {:ok, albergue} <- obtener_albergue(estado, id_albergue),
         :ok <- validar_persona_sin_alojamiento(estado, id_persona),
         :ok <- validar_disponibilidad(albergue),
         {:ok, persona_actualizada} <- Persona.cambiar_estado(persona, :en_albergue),
         {:ok, registro} <- RegistroAlbergue.nuevo(id_albergue, id_persona, :ingreso, opciones) do
      nuevo_albergue = %{albergue | ocupacion_actual: albergue.ocupacion_actual + 1}
      nuevos_albergues = Map.put(estado.albergues, id_albergue, nuevo_albergue)
      nuevas_personas = Map.put(estado.personas, id_persona, persona_actualizada)
      nuevos_registros = Map.put(estado.registros_albergues, registro.id, registro)

      nuevo_estado = %{
        estado
        | personas: nuevas_personas,
          albergues: nuevos_albergues,
          registros_albergues: nuevos_registros
      }

      {:ok, registro, nuevo_estado}
    end
  end

  # ===========================================================================
  # Registrar salida
  # ===========================================================================

  def registrar_salida(estado, id_persona, nuevo_estado_persona \\ :localizada) do
    with {:ok, registro} <- obtener_registro_activo(estado.registros_albergues, id_persona),
         {:ok, albergue} <- obtener_albergue(estado, registro.id_albergue),
         {:ok, persona} <- obtener_persona(estado, id_persona),
         {:ok, persona_actualizada} <- Persona.cambiar_estado(persona, nuevo_estado_persona),
         {:ok, registro_salida} <-
           RegistroAlbergue.nuevo(registro.id_albergue, id_persona, :salida) do
      nuevo_albergue = %{albergue | ocupacion_actual: albergue.ocupacion_actual - 1}
      nuevos_albergues = Map.put(estado.albergues, albergue.id, nuevo_albergue)
      nuevas_personas = Map.put(estado.personas, id_persona, persona_actualizada)
      nuevos_registros = Map.put(estado.registros_albergues, registro_salida.id, registro_salida)

      nuevo_estado = %{
        estado
        | personas: nuevas_personas,
          albergues: nuevos_albergues,
          registros_albergues: nuevos_registros
      }

      {:ok, registro_salida, nuevo_estado}
    end
  end

  # ===========================================================================
  # Consultar cupos disponibles
  # ===========================================================================

  def consultar_cupos(estado, id_albergue) do
    with {:ok, albergue} <- obtener_albergue(estado, id_albergue) do
      disponibles = albergue.capacidad_maxima - albergue.ocupacion_actual

      {:ok, disponibles}
    end
  end

  # ===========================================================================
  # Consultar ocupación
  # ===========================================================================

  def consultar_ocupacion(estado, id_albergue) do
    with {:ok, albergue} <- obtener_albergue(estado, id_albergue) do
      {:ok,
       %{
         albergue: albergue,
         capacidad_maxima: albergue.capacidad_maxima,
         ocupacion_actual: albergue.ocupacion_actual,
         cupos_disponibles: albergue.capacidad_maxima - albergue.ocupacion_actual
       }}
    end
  end


  # ===========================================================================
  # Consulta de albergues
  # ===========================================================================

  def buscar_albergue(estado, identificador) do
  albergue =
    Enum.find(Map.values(estado.albergues), fn albergue ->
      albergue.id == identificador or
        String.downcase(albergue.codigo) ==
          String.downcase(identificador)
    end)

    case albergue do
      nil -> {:error, "El albergue '#{identificador}' no existe"}
      albergue -> {:ok, albergue}
    end
  end

  def listar_albergues(estado) do
    albergues =
      estado.albergues
      |> Map.values()
      |> Enum.sort_by(& &1.codigo)

    {:ok, albergues}
  end

  # ===========================================================================
  #  Reporte de ocupación
  # ===========================================================================

  def reporte_ocupacion(estado) do
    reporte =
      estado.albergues
      |> Map.values()
      |> Enum.map(fn albergue ->
        porcentaje =
          if albergue.capacidad_maxima > 0 do
            albergue.ocupacion_actual / albergue.capacidad_maxima * 100
          else
            0.0
          end

        %{
          id: albergue.id,
          codigo: albergue.codigo,
          nombre: albergue.nombre,
          capacidad_maxima: albergue.capacidad_maxima,
          ocupacion_actual: albergue.ocupacion_actual,
          cupos_disponibles: albergue.capacidad_maxima - albergue.ocupacion_actual,
          porcentaje_ocupacion: Float.round(porcentaje, 2)
        }
      end)
      |> Enum.sort_by(& &1.porcentaje_ocupacion, :desc)

    {:ok, reporte}
  end

  # ===========================================================================
  # Funciones privadas de validación y búsqueda
  # ===========================================================================

  defp obtener_albergue(estado, id) do
    case Map.fetch(estado.albergues, id) do
      {:ok, albergue} -> {:ok, albergue}
      :error -> {:error, "El albergue no existe"}
    end
  end

  defp obtener_persona(estado, id) do
    case Map.fetch(estado.personas, id) do
      {:ok, persona} -> {:ok, persona}
      :error -> {:error, "La persona no existe"}
    end
  end

  defp validar_persona_sin_alojamiento(estado, id_persona) do
    case obtener_registro_activo(estado.registros_albergues, id_persona) do
      {:ok, _registro} -> {:error, "La persona ya se encuentra alojada"}
      {:error, _motivo} -> :ok
    end
  end

  defp validar_disponibilidad(albergue) do
    if albergue.ocupacion_actual < albergue.capacidad_maxima do
      :ok
    else
      {:error, "El albergue no tiene cupos disponibles"}
    end
  end

  defp obtener_registro_activo(registros, id_persona) do
    ultimo_movimiento =
      registros
      |> Map.values()
      |> Enum.filter(&(&1.id_persona == id_persona))
      |> Enum.max_by(&DateTime.to_unix(&1.fecha, :microsecond), fn -> nil end)

    case ultimo_movimiento do
      %{tipo_movimiento: :ingreso} = registro ->
        {:ok, registro}

      _ ->
        {:error, "La persona no tiene un alojamiento activo"}
    end
  end

  defp validar_codigo_unico(albergues, codigo) do
    existe =
      Enum.any?(Map.values(albergues), fn albergue ->
        albergue.codigo == codigo
      end)

    if existe do
      {:error, "El código del albergue ya está registrado"}
    else
      :ok
    end
  end
end
