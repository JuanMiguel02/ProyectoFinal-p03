defmodule Emergencia.Servicios.ServicioPersonas do
  @moduledoc """
  Servicio puro para la gestión de personas afectadas, actualización de su estado
  de localización, trazabilidad de historial y búsquedas avanzadas para familiares.
  """
  alias Emergencia.Persona
  alias Emergencia.Servicios.ServicioActividad

  @estados_permitidos [
    :sin_informacion,
    :reportada,
    :localizada,
    :trasladada,
    :en_albergue,
    :reunificada
  ]

  # ============================================================================
  # 1. Registro de Persona Afectada
  # ============================================================================

  @doc """
  Registra una nueva persona en el sistema. Los datos opcionales (edad,
  dato_referencia, id_familia) se pasan dentro de `opciones`.

  ## Ejemplo:
      # Sin conocer la edad:
      registrar_persona(estado, "Ana Gomez", "12345", "Z-Norte", :reportada)

      # Con edad y datos de referencia opcionales:
      registrar_persona(estado, "Ana Gomez", "12345", "Z-Norte", :reportada, edad: 34, dato_referencia: "Cicatriz en la mejilla")

  La persona recibe automáticamente un UUID interno y un código público `PER-####`.
  """
  def registrar_persona(estado_global, nombre, documento, id_zona, estado, opciones \\ []) do
    with :ok <- validar_id_no_proporcionado(opciones),
         :ok <- validar_nombre(nombre),
         :ok <- validar_documento(documento),
         :ok <- validar_id_zona(id_zona),
         :ok <- validar_estado(estado),
         {:ok, nueva_persona} <- Persona.nueva(nombre, documento, id_zona, estado, opciones),
         :ok <- validar_unicidad_id(estado_global.personas, nueva_persona.id) do
      id_final = nueva_persona.id

      nuevas_personas =
        Map.put(
          estado_global.personas,
          id_final,
          nueva_persona
        )

      estado_actualizado =
        %{estado_global | personas: nuevas_personas}

      id_autor = Keyword.get(opciones, :id_usuario_registro, "SISTEMA")

      descripcion =
        "Registro de persona '#{nombre}' (#{documento}) con ID #{id_final} en estado :#{estado}"

      case ServicioActividad.registrar(
             estado_actualizado,
             id_autor,
             "REGISTRO_PERSONA",
             descripcion
           ) do
        {:ok, estado_final} ->
          {:ok, nueva_persona, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  # ============================================================================
  # 2. Actualización de Estado e Historial de Trazabilidad
  # ============================================================================

  @doc """
  Actualiza el estado de localización de una persona y preserva la estampa
  de tiempo en su historial de estados.
  """
  def cambiar_estado(estado_global, id_persona, nuevo_estado, id_usuario_actualizador) do
    with {:ok, persona} <- obtener_persona(estado_global.personas, id_persona),
         :ok <- validar_estado(nuevo_estado),
         {:ok, persona_actualizada} <- aplicar_cambio_estado(persona, nuevo_estado) do
      nuevas_personas = Map.put(estado_global.personas, id_persona, persona_actualizada)
      estado_actualizado = %{estado_global | personas: nuevas_personas}

      descripcion = "Cambio de estado de persona '#{persona.nombre}' a :#{nuevo_estado}"

      case ServicioActividad.registrar(
             estado_actualizado,
             id_usuario_actualizador,
             "CAMBIO_ESTADO_PERSONA",
             descripcion
           ) do
        {:ok, estado_final} ->
          {:ok, persona_actualizada, estado_final}

        {:error, motivo} ->
          {:error, motivo}
      end
    end
  end

  # ============================================================================
  # 3. Búsquedas Multicriterio (Familiares y Coordinación)
  # ============================================================================

  @doc """
  Busca personas aplicando filtros opcionales (nombre, documento, id_zona, estado).
  Recibe un mapa o keyword list con los criterios de búsqueda.

  ## Ejemplos:
      buscar_personas(mapa, nombre: "Juan")
      buscar_personas(mapa, documento: "12345", estado: :en_albergue)
      buscar_personas(mapa, id_zona: "Z-Norte")
  """
  def buscar_personas(mapa_personas, criterios) do
    mapa_personas
    |> Map.values()
    |> Enum.filter(&cumple_criterios?(&1, criterios))
  end

  @doc """
  Consulta rápida para obtener el historial completo de ubicaciones y estados
  de una persona por su ID o Documento.
  """
  def consultar_historial(mapa_personas, documento_o_id) do
    case Enum.find(Map.values(mapa_personas), fn p ->
           p.id == documento_o_id or p.documento == documento_o_id
         end) do
      nil -> {:error, "No se encontró ningún registro para '#{documento_o_id}'"}
      persona -> {:ok, persona.nombre, persona.estado, persona.historial_estados}
    end
  end

  # ============================================================================
  # Funciones Privadas de Filtrado y Validación
  # ============================================================================

  defp obtener_persona(mapa_personas, id) do
    case Map.fetch(mapa_personas, id) do
      {:ok, persona} -> {:ok, persona}
      :error -> {:error, "La persona con ID '#{id}' no existe"}
    end
  end

  defp validar_unicidad_id(mapa_personas, id) do
    if Map.has_key?(mapa_personas, id) do
      {:error, "Ya existe una persona registrada con el ID '#{id}'"}
    else
      :ok
    end
  end

  defp validar_id_no_proporcionado(opciones) do
    campos_id = [:id, :codigo_persona]

    case Enum.find(campos_id, &Keyword.has_key?(opciones, &1)) do
      nil -> :ok
      campo -> {:error, "El campo #{campo} se genera automáticamente y no debe proporcionarse"}
    end
  end

  defp validar_nombre(nombre) when is_binary(nombre) do
    if String.trim(nombre) != "", do: :ok, else: {:error, "El nombre no puede estar vacío"}
  end

  defp validar_nombre(_), do: {:error, "El nombre debe ser texto"}

  defp validar_documento(documento) when is_binary(documento) do
    if String.trim(documento) != "", do: :ok, else: {:error, "El documento no puede estar vacío"}
  end

  defp validar_documento(_), do: {:error, "El documento debe ser texto"}

  defp validar_id_zona(id_zona) when is_binary(id_zona) do
    if String.trim(id_zona) != "", do: :ok, else: {:error, "El ID de zona no puede estar vacío"}
  end

  defp validar_id_zona(_), do: {:error, "El ID de zona debe ser texto"}

  defp validar_estado(estado) do
    if estado in @estados_permitidos do
      :ok
    else
      {:error, "Estado inválido. Permitidos: #{inspect(@estados_permitidos)}"}
    end
  end

  defp aplicar_cambio_estado(persona, nuevo_estado) do
    nuevo_registro_historial = {nuevo_estado, DateTime.utc_now()}
    historial_actualizado = [nuevo_registro_historial | persona.historial_estados]

    {:ok, %{persona | estado: nuevo_estado, historial_estados: historial_actualizado}}
  end

  # Evalúa dinámicamente si una persona satisface todos los filtros pasados en la búsqueda
  defp cumple_criterios?(persona, criterios) do
    Enum.all?(criterios, fn
      {:nombre, termino} ->
        String.contains?(String.downcase(persona.nombre), String.downcase(termino))

      {:documento, doc} ->
        String.contains?(persona.documento, doc)

      {:id_zona, zona_id} ->
        persona.id_zona == zona_id

      {:estado, est} ->
        persona.estado == est

      _criterio_desconocido ->
        true
    end)
  end
end
