defmodule Emergencia.Servicios.ServicioPersonas do
  @moduledoc """
  Servicio puro para la gestión de personas afectadas, actualización de su estado
  de localización, trazabilidad de historial y búsquedas avanzadas para familiares.
  """
  alias Emergencia.Persona
  alias Emergencia.EstadoPoblacion
  alias Emergencia.GeneradorID

  @estados_permitidos [
    :sin_informacion,
    :reportada,
    :localizada,
    :trasladada,
    :en_albergue,
    :reunificada
  ]

  # ============================================================================
  # Registro de Persona Afectada
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
  def registrar(estado, nombre, documento, id_zona, estado_persona, opciones \\ []) do
    codigo_persona = GeneradorID.generar("PER", estado.personas, & &1.codigo_persona)

    with :ok <- validar_id_no_proporcionado(opciones),
         :ok <- validar_nombre(nombre),
         :ok <- validar_documento(documento),
         :ok <- validar_id_zona(id_zona),
         :ok <- validar_estado(estado_persona),
         :ok <- validar_documento_unico(estado.personas, documento),
         {:ok, nueva_persona} <-
           Persona.nueva(nombre, codigo_persona, documento, id_zona, estado_persona, opciones) do
      nuevas_personas = Map.put(estado.personas, nueva_persona.id, nueva_persona)

      estado_actualizado = %{estado | personas: nuevas_personas}

      {:ok, nueva_persona, estado_actualizado}
    end
  end

  # ============================================================================
  # Actualización de Estado e Historial de Trazabilidad
  # ============================================================================

  @doc """
  Actualiza el estado de localización de una persona y preserva la estampa
  de tiempo en su historial de estados.
  """
  def cambiar_estado(%EstadoPoblacion{} = estado, id_persona, nuevo_estado) do
    with {:ok, persona} <- obtener_persona(estado.personas, id_persona),
         :ok <- validar_estado(nuevo_estado),
         {:ok, persona_actualizada} <- Persona.cambiar_estado(persona, nuevo_estado) do
      nuevas_personas = Map.put(estado.personas, persona.id, persona_actualizada)
      estado_actualizado = %{estado | personas: nuevas_personas}

      {:ok, persona_actualizada, estado_actualizado}
    end
  end

  # ============================================================================
  # Búsquedas Multicriterio (Familiares y Coordinación)
  # ============================================================================

  def consultar_persona(personas, id_persona) do
    obtener_persona(personas, id_persona)
  end

  def buscar_personas(%EstadoPoblacion{} = estado, criterios) do
    personas =
      estado.personas
      |> Map.values()
      |> Enum.filter(&cumple_criterios?(&1, criterios))

    {:ok, personas}
  end

  def asignar_a_familia(%EstadoPoblacion{} = estado, id_persona, id_familia) do
    with {:ok, persona} <- obtener_persona(estado.personas, id_persona),
         :ok <- validar_familia_existente(estado.familias, id_familia) do
      persona_actualizada = %{persona | id_familia: id_familia}
      nuevas_personas = Map.put(estado.personas, persona.id, persona_actualizada)
      nuevo_estado = %{estado | personas: nuevas_personas}

      {:ok, persona_actualizada, nuevo_estado}
    end
  end

  @doc """
  Consulta rápida para obtener el historial completo de ubicaciones y estados
  de una persona por su ID o Documento.
  """
  def consultar_historial(%EstadoPoblacion{} = estado, documento_o_id) do
    case Enum.find(Map.values(estado.personas), fn persona ->
           persona.id == documento_o_id or persona.documento == documento_o_id
         end) do
      nil ->
        {:error, "No se encontró ningún registro para '#{documento_o_id}'"}

      persona ->
        {:ok,
         %{
           nombre: persona.nombre,
           estado: persona.estado,
           historial_estados: persona.historial_estados
         }}
    end
  end

  @doc """
  Cuenta recursivamente cuántas personas se encuentran en un estado específico.
  """
  def contar_por_estado(estado, estado_buscado) do
    personas_lista = Map.values(estado.personas)
    total = contar_estado_recursivo(personas_lista, estado_buscado, 0)
    {:ok, total}
  end

  defp contar_estado_recursivo([], _estado_buscado, total_acumulado), do: total_acumulado

  defp contar_estado_recursivo([persona | resto], estado_buscado, total_acumulado) do
    if persona.estado == estado_buscado do
      contar_estado_recursivo(resto, estado_buscado, total_acumulado + 1)
    else
      contar_estado_recursivo(resto, estado_buscado, total_acumulado)
    end
  end

  # ============================================================================
  # Funciones Privadas de Filtrado y Validación
  # ============================================================================

  defp obtener_persona(personas, id_persona) do
    case Map.fetch(personas, id_persona) do
      {:ok, persona} ->
        {:ok, persona}

      :error ->
        {:error, "La persona con ID '#{id_persona}' no existe"}
    end
  end

  defp validar_familia_existente(familias, id_familia) do
    if Map.has_key?(familias, id_familia) do
      :ok
    else
      {:error, "La familia no existe"}
    end
  end

  defp validar_documento_unico(personas, documento) do
    existe =
      Enum.any?(personas, fn {_id, persona} ->
        persona.documento == documento
      end)

    if existe do
      {:error, "Ya existe una persona registrada con ese documento"}
    else
      :ok
    end
  end

  defp validar_id_no_proporcionado(opciones) do
    campos_id = [:id, :codigo_persona]

    case Enum.find(campos_id, &Keyword.has_key?(opciones, &1)) do
      nil ->
        :ok

      campo ->
        {:error, "El campo #{campo} se genera automáticamente y no debe proporcionarse"}
    end
  end

  defp validar_nombre(nombre) when is_binary(nombre) do
    if String.trim(nombre) != "" do
      :ok
    else
      {:error, "El nombre no puede estar vacío"}
    end
  end

  defp validar_nombre(_), do: {:error, "El nombre debe ser texto"}

  defp validar_documento(documento) when is_binary(documento) do
    if String.trim(documento) != "" do
      :ok
    else
      {:error, "El documento no puede estar vacío"}
    end
  end

  defp validar_documento(_), do: {:error, "El documento debe ser texto"}

  defp validar_id_zona(id_zona) when is_binary(id_zona) do
    if String.trim(id_zona) != "" do
      :ok
    else
      {:error, "El ID de zona no puede estar vacío"}
    end
  end

  defp validar_id_zona(_), do: {:error, "El ID de zona debe ser texto"}

  defp validar_estado(estado) do
    if estado in @estados_permitidos do
      :ok
    else
      {:error, "Estado inválido. Permitidos: #{inspect(@estados_permitidos)}"}
    end
  end

  defp cumple_criterios?(persona, criterios) do
    Enum.all?(criterios, fn
      {:nombre, termino} when is_binary(termino) ->
        String.contains?(
          String.downcase(persona.nombre),
          String.downcase(termino)
        )

      {:documento, documento} when is_binary(documento) ->
        String.contains?(persona.documento, documento)

      {:codigo_persona, codigo} when is_binary(codigo) ->
        String.downcase(persona.codigo_persona) ==
          String.downcase(codigo)

      {:id_zona, id_zona} ->
        persona.id_zona == id_zona

      {:estado, estado} ->
        persona.estado == estado

      _criterio_desconocido ->
        true
    end)
  end
end
