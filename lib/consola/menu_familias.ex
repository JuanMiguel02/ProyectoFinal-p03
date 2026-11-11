defmodule Emergencia.Consola.MenuFamilias do
  @moduledoc """
  Gestiona la interfaz de consola para las operaciones
  relacionadas con las familias.
  """

  alias Emergencia.Aplicacion.GestionFamilias
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n========== GESTIÓN DE FAMILIAS ==========", :mensaje)
    Util.mostrar("1. Registrar familia", :mensaje)
    Util.mostrar("2. Buscar familia", :mensaje)
    Util.mostrar("3. Listar familias", :mensaje)
    Util.mostrar("4. Consultar integrantes", :mensaje)
    Util.mostrar("5. Asignar persona a familia", :mensaje)
    Util.mostrar("6. Volver", :mensaje)

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
    Util.mostrar(inspect(resultado, pretty: true, limit: :infinity), :mensaje)
  end

  defp mostrar_resultado({:ok, resultado, {:advertencia, motivo}}, mensaje) do
    Util.mostrar("\n#{mensaje}", :mensaje)
    Util.mostrar(inspect(resultado, pretty: true, limit: :infinity), :mensaje)
    Util.mostrar("\nAdvertencia:", :error)
    Util.mostrar(inspect(motivo, pretty: true), :error)
  end

  defp mostrar_resultado({:error, motivo}, _mensaje) do
    Util.mostrar("\nNo se pudo completar la operación:", :error)
    Util.mostrar(inspect(motivo, pretty: true), :error)
  end

  defp mostrar_resultado(otro, _mensaje) do
    Util.mostrar("\nResultado:", :mensaje)
    Util.mostrar(inspect(otro, pretty: true, limit: :infinity), :mensaje)
  end
end
