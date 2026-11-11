defmodule Emergencia.Consola.MenuAlbergues do
  @moduledoc """
  Gestiona la interfaz de consola para las operaciones
  relacionadas con los albergues.
  """

  alias Emergencia.Aplicacion.GestionAlbergues
  alias Emergencia.Aplicacion.GestionPersonas
  alias Emergencia.Consola.FormatoConsola
  alias Emergencia.Consola.PermisosMenu
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n========== GESTIÓN DE ALBERGUES ==========", :mensaje)

    PermisosMenu.mostrar_opciones(sesion, [
      {"1", "Registrar albergue", :registrar_albergue},
      {"2", "Ingresar persona a un albergue", :ingreso_albergue},
      {"3", "Registrar salida de una persona", :salida_albergue},
      {"4", "Consultar cupos disponibles", :consultar_albergues},
      {"5", "Consultar ocupación de un albergue", :consultar_albergues},
      {"6", "Reporte general de ocupación", :consultar_albergues},
      {"7", "Volver", nil}
    ])

    opcion = Util.ingresar("\nSeleccione una opción: ", :texto)

    case opcion do
      "1" ->
        registrar_albergue(sesion)

      "2" ->
        ingresar_persona(sesion)

      "3" ->
        registrar_salida(sesion)

      "4" ->
        consultar_cupos(sesion)

      "5" ->
        consultar_ocupacion(sesion)

      "6" ->
        reporte_ocupacion(sesion)

      "7" ->
        :ok

      _ ->
        Util.mostrar("\nOpción no válida.", :error)
        iniciar(sesion)
    end
  end

  # ============================================================
  # REGISTRAR ALBERGUE
  # ============================================================

  defp registrar_albergue(sesion) do
    Util.mostrar("\n========== REGISTRAR ALBERGUE ==========", :mensaje)

    nombre =
      Util.ingresar("Nombre del albergue: ", :texto)

    codigo_zona =
      Util.ingresar("Código de la zona: ", :texto)

    capacidad_maxima =
      Util.ingresar("Capacidad máxima: ", :entero)

    case GestionAlbergues.registrar_albergue(
           sesion,
           nombre,
           codigo_zona,
           capacidad_maxima
         ) do
      {:ok, albergue} ->
        Util.mostrar("\nAlbergue registrado correctamente.", :mensaje)
        mostrar_albergue(albergue)

      {:ok, albergue, {:advertencia, motivo}} ->
        Util.mostrar(
          "\nAlbergue registrado, pero ocurrió una advertencia: #{inspect(motivo)}",
          :error
        )

        mostrar_albergue(albergue)

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # INGRESAR PERSONA
  # ============================================================

  defp ingresar_persona(sesion) do
    Util.mostrar("\n========== INGRESAR PERSONA ==========", :mensaje)

    case seleccionar_persona(sesion) do
      {:ok, persona} ->
        case seleccionar_albergue(sesion) do
          {:ok, albergue} ->
            case GestionAlbergues.ingresar_persona(
                   sesion,
                   persona.id,
                   albergue.id
                 ) do
              {:ok, registro} ->
                mostrar_registro(registro, persona, albergue)

              {:ok, registro, {:advertencia, motivo}} ->
                mostrar_registro(registro, persona, albergue)
                Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

              {:error, motivo} ->
                Util.mostrar("\n#{motivo}", :error)
            end

          {:error, motivo} ->
            Util.mostrar("\n#{motivo}", :error)
        end

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # REGISTRAR SALIDA
  # ============================================================

  defp registrar_salida(sesion) do
    Util.mostrar("\n========== REGISTRAR SALIDA ==========", :mensaje)

    case seleccionar_persona(sesion) do
      {:ok, persona} ->
        Util.mostrar(
          "\nPersona seleccionada: #{persona.nombre}",
          :mensaje
        )

        confirmar =
          Util.ingresar(
            "¿Desea registrar su salida? (s/n): ",
            :texto
          )

        if String.downcase(confirmar) == "s" do
          case GestionAlbergues.registrar_salida(sesion, persona.id) do
            {:ok, registro} ->
              mostrar_salida(registro, persona)

            {:ok, registro, {:advertencia, motivo}} ->
              mostrar_salida(registro, persona)
              Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)

            {:error, motivo} ->
              Util.mostrar("\n#{motivo}", :error)
          end
        else
          Util.mostrar("\nOperación cancelada.", :mensaje)
        end

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # CONSULTAR CUPOS DISPONIBLES
  # ============================================================

  defp consultar_cupos(sesion) do
    Util.mostrar("\n========== CONSULTAR CUPOS ==========", :mensaje)

    case seleccionar_albergue(sesion) do
      {:ok, albergue} ->
        case GestionAlbergues.consultar_cupos(
               sesion,
               albergue.id
             ) do
          {:ok, disponibles} ->
            Util.mostrar(
              "\nCupos disponibles en #{albergue.nombre}: #{disponibles}",
              :mensaje
            )

          {:error, motivo} ->
            Util.mostrar("\n#{motivo}", :error)
        end

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # CONSULTAR OCUPACIÓN
  # ============================================================

  defp consultar_ocupacion(sesion) do
    Util.mostrar("\n========== CONSULTAR OCUPACIÓN ==========", :mensaje)

    case seleccionar_albergue(sesion) do
      {:ok, albergue} ->
        case GestionAlbergues.consultar_ocupacion(
               sesion,
               albergue.id
             ) do
          {:ok, ocupacion} ->
            Util.mostrar("\n---------- OCUPACIÓN ----------", :mensaje)
            Util.mostrar("Albergue: #{albergue.nombre}", :mensaje)
            Util.mostrar("Capacidad máxima: #{ocupacion.capacidad_maxima}", :mensaje)
            Util.mostrar("Ocupación actual: #{ocupacion.ocupacion_actual}", :mensaje)
            Util.mostrar("Cupos disponibles: #{ocupacion.cupos_disponibles}", :mensaje)

          {:error, motivo} ->
            Util.mostrar("\n#{motivo}", :error)
        end

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # REPORTE GENERAL DE OCUPACIÓN
  # ============================================================

  defp reporte_ocupacion(sesion) do
    Util.mostrar("\n========== REPORTE DE OCUPACIÓN ==========", :mensaje)

    case GestionAlbergues.reporte_ocupacion(sesion) do
      {:ok, []} ->
        Util.mostrar("\nNo hay albergues registrados.", :mensaje)

      {:ok, reporte} ->
        Enum.each(reporte, fn albergue ->
          Util.mostrar("\n---------- ALBERGUE ----------", :mensaje)
          Util.mostrar("Código: #{albergue.codigo}", :mensaje)
          Util.mostrar("Nombre: #{albergue.nombre}", :mensaje)
          Util.mostrar("Capacidad: #{albergue.capacidad_maxima}", :mensaje)
          Util.mostrar("Ocupación: #{albergue.ocupacion_actual}", :mensaje)
          Util.mostrar("Disponibles: #{albergue.cupos_disponibles}", :mensaje)

          Util.mostrar(
            "Porcentaje de ocupación: #{albergue.porcentaje_ocupacion}%",
            :mensaje
          )
        end)

      {:error, motivo} ->
        Util.mostrar("\n#{motivo}", :error)
    end

    iniciar(sesion)
  end

  # ============================================================
  # SELECCIONAR ALBERGUE
  # ============================================================

  defp seleccionar_albergue(sesion) do
    case GestionAlbergues.listar_albergues(sesion) do
      {:ok, []} ->
        {:error, "No hay albergues registrados."}

      {:ok, albergues} ->
        Util.mostrar("\n========== ALBERGUES DISPONIBLES ==========", :mensaje)

        Enum.each(albergues, fn albergue ->
          Util.mostrar(
            "#{albergue.codigo} - #{albergue.nombre} | " <>
              "Disponibles: #{albergue.capacidad_maxima - albergue.ocupacion_actual}",
            :mensaje
          )
        end)

        codigo =
          Util.ingresar(
            "\nIngrese el código o ID del albergue: ",
            :texto
          )

        case Enum.find(albergues, fn albergue ->
               albergue.id == codigo or
                 String.downcase(albergue.codigo) == String.downcase(codigo)
             end) do
          nil ->
            {:error, "No existe un albergue con ese código."}

          albergue ->
            {:ok, albergue}
        end

      {:error, motivo} ->
        {:error, motivo}
    end
  end

  # ============================================================
  # SELECCIONAR PERSONA
  # ============================================================

  defp seleccionar_persona(sesion) do
    Util.mostrar("\n========== BUSCAR PERSONA ==========", :mensaje)
    Util.mostrar("1. Buscar por código", :mensaje)
    Util.mostrar("2. Buscar por documento", :mensaje)

    opcion =
      Util.ingresar("\nSeleccione un criterio: ", :texto)

    criterios =
      case opcion do
        "1" ->
          codigo =
            Util.ingresar("Código de persona: ", :texto)

          [codigo_persona: codigo]

        "2" ->
          documento =
            Util.ingresar("Documento: ", :texto)

          [documento: documento]

        _ ->
          nil
      end

    case criterios do
      nil ->
        {:error, "Opción no válida."}

      _ ->
        case GestionPersonas.buscar_personas(sesion, criterios) do
          {:ok, [persona]} ->
            mostrar_persona_seleccionada(persona)
            {:ok, persona}

          {:ok, []} ->
            {:error, "No se encontró ninguna persona."}

          {:ok, _personas} ->
            {:error, "Se encontraron varias personas. Utilice un identificador más específico."}

          {:error, motivo} ->
            {:error, motivo}
        end
    end
  end

  # ============================================================
  # MOSTRAR ALBERGUE
  # ============================================================

  defp mostrar_albergue(albergue) do
    Util.mostrar("Código: #{albergue.codigo}", :mensaje)
    Util.mostrar("Nombre: #{albergue.nombre}", :mensaje)
    Util.mostrar("Capacidad máxima: #{albergue.capacidad_maxima}", :mensaje)
    Util.mostrar("Ocupación actual: #{albergue.ocupacion_actual}", :mensaje)
  end

  defp mostrar_persona_seleccionada(persona) do
    Util.mostrar("\n---------- PERSONA SELECCIONADA ----------", :mensaje)
    Util.mostrar("Nombre: #{persona.nombre}", :mensaje)
    Util.mostrar("Código: #{persona.codigo_persona}", :mensaje)
    Util.mostrar("Documento: #{persona.documento}", :mensaje)
    Util.mostrar("Estado: #{FormatoConsola.estado(persona.estado)}", :mensaje)
    Util.mostrar("Edad: #{persona.edad || "No especificada"}", :mensaje)
    Util.mostrar("Descripción: #{persona.dato_referencia || "No especificada"}", :mensaje)
  end

  defp mostrar_registro(registro, persona, albergue) do
    Util.mostrar("\nIngreso registrado correctamente.", :mensaje)
    Util.mostrar("Persona: #{persona.nombre} (#{persona.codigo_persona})", :mensaje)
    Util.mostrar("Albergue: #{albergue.nombre} (#{albergue.codigo})", :mensaje)
    Util.mostrar("Fecha y hora: #{FormatoConsola.fecha_hora(registro.fecha)}", :mensaje)
  end

  defp mostrar_salida(registro, persona) do
    Util.mostrar("\nSalida registrada correctamente.", :mensaje)
    Util.mostrar("Persona: #{persona.nombre} (#{persona.codigo_persona})", :mensaje)
    Util.mostrar("Fecha y hora: #{FormatoConsola.fecha_hora(registro.fecha)}", :mensaje)
  end
end
