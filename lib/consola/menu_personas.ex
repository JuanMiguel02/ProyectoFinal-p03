defmodule Emergencia.Consola.MenuPersonas do
  @moduledoc """
  Gestiona la interfaz de consola para las operaciones
  relacionadas con las personas afectadas.
  """

  alias Emergencia.Aplicacion.GestionPersonas
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n========== GESTIÓN DE PERSONAS ==========", :mensaje)
    Util.mostrar("1. Registrar persona", :mensaje)
    Util.mostrar("2. Buscar persona", :mensaje)
    Util.mostrar("3. Listar personas", :mensaje)
    Util.mostrar("4. Cambiar estado de una persona", :mensaje)
    Util.mostrar("5. Consultar historial de una persona", :mensaje)
    Util.mostrar("6. Volver", :mensaje)

    opcion = Util.ingresar("\nSeleccione una opción: ", :texto)

    case opcion do
      "1" ->
        registrar_persona(sesion)

      "2" ->
        buscar_personas(sesion)

      "3" ->
        listar_personas(sesion)

      "4" ->
        cambiar_estado(sesion)

      "5" ->
        consultar_historial(sesion)

      "6" ->
        :ok

      _ ->
        Util.mostrar("\nOpción no válida.", :error)
        iniciar(sesion)
    end
  end

  # ============================================================
  # REGISTRAR PERSONA
  # ============================================================

  defp registrar_persona(sesion) do
    Util.mostrar("\n========== REGISTRAR PERSONA ==========", :mensaje)

    nombre =
      Util.ingresar("Nombre completo: ", :texto)

    documento =
      Util.ingresar("Documento: ", :texto)

    codigo_zona =
      Util.ingresar("Código de la zona: ", :texto)

    edad_texto =
      Util.ingresar("Edad (deje vacío si no se conoce): ", :texto)

    dato_referencia =
      Util.ingresar("Dato de referencia (opcional): ", :texto)

    case seleccionar_estado() do
      {:ok, estado} ->
        opciones =
          []
          |> agregar_opcional(:edad, edad_texto)
          |> agregar_opcional(:dato_referencia, dato_referencia)

        case GestionPersonas.registrar_persona(
               sesion,
               nombre,
               documento,
               codigo_zona,
               estado,
               opciones
             ) do
          {:ok, persona} ->
            Util.mostrar(
              "\nPersona registrada correctamente.",
              :mensaje
            )

            Util.mostrar("Código: #{persona.codigo_persona}", :mensaje)
            Util.mostrar("Nombre: #{persona.nombre}", :mensaje)

          {:ok, persona, {:advertencia, motivo}} ->
            Util.mostrar(
              "\nPersona registrada, pero ocurrió una advertencia: #{inspect(motivo)}",
              :error
            )

            Util.mostrar("Código: #{persona.codigo_persona}", :mensaje)

          {:error, motivo} ->
            Util.mostrar("\n#{motivo}", :error)
        end

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # BUSCAR PERSONA
  # ============================================================

  defp buscar_personas(sesion) do
    Util.mostrar("\n========== BUSCAR PERSONAS ==========", :mensaje)
    Util.mostrar("1. Buscar por nombre", :mensaje)
    Util.mostrar("2. Buscar por documento", :mensaje)
    Util.mostrar("3. Buscar por código", :mensaje)
    Util.mostrar("4. Buscar por estado", :mensaje)
    Util.mostrar("5. Buscar por zona", :mensaje)

    opcion = Util.ingresar("\nSeleccione un criterio: ", :texto)

    criterios =
      case opcion do
        "1" ->
          nombre = Util.ingresar("Nombre: ", :texto)
          [nombre: nombre]

        "2" ->
          documento = Util.ingresar("Documento: ", :texto)
          [documento: documento]

        "3" ->
          codigo = Util.ingresar("Código de persona: ", :texto)
          [codigo_persona: codigo]

        "4" ->
          case seleccionar_estado() do
            {:ok, estado} ->
              [estado: estado]

            {:error, motivo} ->
              Util.mostrar("\n#{motivo}", :error)
              nil
          end

        "5" ->
          codigo_zona = Util.ingresar("Código de la zona: ", :texto)
          [codigo_zona: codigo_zona]

        _ ->
          Util.mostrar("\nOpción no válida.", :error)
          nil
      end

    if criterios != nil do
      case GestionPersonas.buscar_personas(sesion, criterios) do
        {:ok, []} ->
          Util.mostrar("\nNo se encontraron personas.", :mensaje)

        {:ok, personas} ->
          Enum.each(personas, &mostrar_persona/1)

        {:error, motivo} ->
          Util.mostrar("\n#{motivo}", :error)
      end
    end

    iniciar(sesion)
  end

  # ============================================================
  # LISTAR PERSONAS
  # ============================================================

  defp listar_personas(sesion) do
    case GestionPersonas.listar_personas(sesion) do
      {:ok, personas} ->
        if Enum.empty?(personas) do
          Util.mostrar("\nNo hay personas registradas.", :mensaje)
        else
          Enum.each(personas, &mostrar_persona/1)
        end

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # CAMBIAR ESTADO
  # ============================================================

  defp cambiar_estado(sesion) do
    Util.mostrar("\n========== CAMBIAR ESTADO DE PERSONA ==========", :mensaje)
    Util.mostrar("1. Buscar por código de persona", :mensaje)
    Util.mostrar("2. Buscar por documento", :mensaje)

    opcion = Util.ingresar("\nSeleccione una opción: ", :texto)

    criterios =
      case opcion do
        "1" ->
          codigo =
            Util.ingresar("\nIngrese el código de persona: ", :texto)

          [codigo_persona: codigo]

        "2" ->
          documento =
            Util.ingresar("\nIngrese el documento de la persona: ", :texto)

          [documento: documento]

        _ ->
          Util.mostrar("\nOpción no válida.", :error)
          nil
      end

    if criterios != nil do
      case GestionPersonas.buscar_personas(sesion, criterios) do
        {:ok, [persona]} ->
          Util.mostrar(
            "\nPersona encontrada: #{persona.nombre}",
            :mensaje
          )

          case seleccionar_estado() do
            {:ok, nuevo_estado} ->
              case GestionPersonas.cambiar_estado(
                     sesion,
                     persona.id,
                     nuevo_estado
                   ) do
                {:ok, _persona} ->
                  Util.mostrar(
                    "\nEstado de la persona actualizado correctamente.",
                    :mensaje
                  )

                {:error, motivo} ->
                  Util.mostrar("\n#{motivo}", :error)
              end

            {:error, motivo} ->
              Util.mostrar("\n#{motivo}", :error)
          end

        {:ok, []} ->
          Util.mostrar("\nNo se encontró la persona.", :error)

        {:ok, _personas} ->
          Util.mostrar(
            "\nSe encontraron varias personas. Utilice un identificador más específico.",
            :error
          )

        {:error, motivo} ->
          Util.mostrar("\n#{motivo}", :error)
      end
    end

    iniciar(sesion)
  end

  defp seleccionar_estado do
    estados = [
      {"1", :sin_informacion, "Sin información"},
      {"2", :reportada, "Reportada"},
      {"3", :localizada, "Localizada"},
      {"4", :trasladada, "Trasladada"},
      {"5", :en_albergue, "En albergue"},
      {"6", :reunificada, "Reunificada"}
    ]

    Util.mostrar("\n========== ESTADOS DISPONIBLES ==========", :mensaje)

    Enum.each(estados, fn {numero, _estado, descripcion} ->
      Util.mostrar("#{numero}. #{descripcion}", :mensaje)
    end)

    opcion = Util.ingresar("\nSeleccione el nuevo estado: ", :texto)

    case Enum.find(estados, fn {numero, _, _} -> numero == opcion end) do
      {_numero, estado, _descripcion} ->
        {:ok, estado}

      nil ->
        {:error, "Opción no válida. Seleccione un estado disponible."}
    end
  end

  # ============================================================
  # CONSULTAR HISTORIAL
  # ============================================================

  defp consultar_historial(sesion) do
    identificador =
      Util.ingresar(
        "\nIngrese el código o documento de la persona: ",
        :texto
      )

    case GestionPersonas.consultar_historial(sesion, identificador) do
      {:ok, []} ->
        Util.mostrar(
          "\nLa persona no tiene registros en su historial.",
          :mensaje
        )

      {:ok, historial} ->
        Util.mostrar("\n========== HISTORIAL DE LA PERSONA ==========", :mensaje)

        Enum.each(historial, fn registro ->
          Util.mostrar(inspect(registro, pretty: true), :mensaje)
        end)

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # MOSTRAR PERSONA
  # ============================================================

  defp mostrar_persona(persona) do
    Util.mostrar("\n---------- PERSONA ----------", :mensaje)
    Util.mostrar("Código: #{persona.codigo_persona}", :mensaje)
    Util.mostrar("Nombre: #{persona.nombre}", :mensaje)
    Util.mostrar("Documento: #{persona.documento}", :mensaje)
    Util.mostrar("Estado: #{persona.estado}", :mensaje)
  end

  defp agregar_opcional(opciones, :edad, ""), do: opciones

  defp agregar_opcional(opciones, :edad, edad_texto) do
    case Integer.parse(edad_texto) do
      {edad, ""} when edad >= 0 ->
        Keyword.put(opciones, :edad, edad)

      _ ->
        opciones
    end
  end

  defp agregar_opcional(opciones, :dato_referencia, ""), do: opciones

  defp agregar_opcional(opciones, clave, valor) do
    Keyword.put(opciones, clave, valor)
  end
end
