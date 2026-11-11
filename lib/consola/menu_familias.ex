defmodule Emergencia.Consola.MenuFamilias do
  @moduledoc """
  Gestiona la interfaz de consola para las operaciones
  relacionadas con las familias.
  """

  alias Emergencia.Aplicacion.GestionFamilias
  alias Emergencia.Consola.FormatoConsola
  alias Emergencia.Consola.PermisosMenu
  alias Emergencia.Familia
  alias Emergencia.Persona
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n========== GESTIÓN DE FAMILIAS ==========", :mensaje)

    PermisosMenu.mostrar_opciones(sesion, [
      {"1", "Registrar familia", :registrar_familia},
      {"2", "Buscar familia", :consultar_familias},
      {"3", "Listar familias", :consultar_familias},
      {"4", "Consultar integrantes", :consultar_familias},
      {"5", "Asignar persona a familia", :asignar_familia},
      {"6", "Volver", nil}
    ])

    opcion = Util.ingresar("Seleccione una opción: ", :texto)

    case opcion do
      "1" ->
        registrar_familia(sesion)

      "2" ->
        buscar_familia(sesion)

      "3" ->
        listar_familias(sesion)

      "4" ->
        consultar_integrantes(sesion)

      "5" ->
        asignar_persona(sesion)

      "6" ->
        :ok

      _ ->
        Util.mostrar("\nOpción no válida.", :error)
        iniciar(sesion)
    end
  end

  defp registrar_familia(sesion) do
    Util.mostrar("\n========== REGISTRAR FAMILIA ==========", :mensaje)
    nombre = Util.ingresar("Nombre de la familia: ", :texto)

    sesion
    |> GestionFamilias.registrar_familia(nombre)
    |> mostrar_resultado("Familia registrada correctamente.")

    iniciar(sesion)
  end

  defp buscar_familia(sesion) do
    Util.mostrar("\n========== BUSCAR FAMILIA ==========", :mensaje)
    identificador = Util.ingresar("Código o UUID de la familia: ", :texto)

    sesion
    |> GestionFamilias.buscar_familia(identificador)
    |> mostrar_resultado("Familia encontrada.")

    iniciar(sesion)
  end

  defp listar_familias(sesion) do
    Util.mostrar("\n========== LISTADO DE FAMILIAS ==========", :mensaje)

    sesion
    |> GestionFamilias.listar_familias()
    |> mostrar_resultado("Familias registradas:")

    iniciar(sesion)
  end

  defp consultar_integrantes(sesion) do
    Util.mostrar("\n========== INTEGRANTES DE UNA FAMILIA ==========", :mensaje)
    identificador = Util.ingresar("Código o UUID de la familia: ", :texto)

    sesion
    |> GestionFamilias.consultar_integrantes(identificador)
    |> mostrar_resultado("Integrantes de la familia:")

    iniciar(sesion)
  end

  defp asignar_persona(sesion) do
    Util.mostrar("\n========== ASIGNAR PERSONA A FAMILIA ==========", :mensaje)
    id_persona = Util.ingresar("Código o documento de la persona: ", :texto)
    id_familia = Util.ingresar("Código o UUID de la familia: ", :texto)

    sesion
    |> GestionFamilias.asignar_persona(id_persona, id_familia)
    |> mostrar_resultado("Persona asignada correctamente.")

    iniciar(sesion)
  end

  defp mostrar_resultado({:ok, resultado}, mensaje) do
    Util.mostrar("\n#{mensaje}", :mensaje)

    if resultado == [] do
      texto =
        if mensaje == "Integrantes de la familia:",
          do: "La familia no tiene integrantes registrados.",
          else: "No hay familias registradas."

      Util.mostrar(texto, :mensaje)
    else
      mostrar_detalle(resultado)
    end
  end

  defp mostrar_resultado({:ok, resultado, {:advertencia, motivo}}, mensaje) do
    Util.mostrar("\n#{mensaje}", :mensaje)
    mostrar_detalle(resultado)
    Util.mostrar("Advertencia de auditoría: #{inspect(motivo)}", :error)
  end

  defp mostrar_resultado({:error, motivo}, _mensaje) do
    Util.mostrar("\nNo se pudo completar la operación: #{inspect(motivo)}", :error)
  end

  defp mostrar_detalle(%Familia{} = familia) do
    Util.mostrar("Código: #{familia.codigo_familia}", :mensaje)
    Util.mostrar("Nombre: #{familia.nombre}", :mensaje)
  end

  defp mostrar_detalle(%Persona{} = persona) do
    Util.mostrar("Nombre: #{persona.nombre}", :mensaje)
    Util.mostrar("Código: #{persona.codigo_persona}", :mensaje)
    Util.mostrar("Documento: #{persona.documento}", :mensaje)
    Util.mostrar("Estado: #{FormatoConsola.estado(persona.estado)}", :mensaje)
  end

  defp mostrar_detalle(personas) when is_list(personas) do
    case personas do
      [] ->
        Util.mostrar("No hay integrantes registrados.", :mensaje)

      _ ->
        Enum.each(personas, fn persona ->
          Util.mostrar("\n---------- INTEGRANTE ----------", :mensaje)
          mostrar_detalle(persona)
        end)
    end
  end
end
