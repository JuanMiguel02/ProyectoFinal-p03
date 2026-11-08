defmodule Emergencia.Consola.MenuPrincipal do
  @moduledoc """
  Gestiona el menú principal del sistema de emergencias.

  Permite acceder a los diferentes módulos según el rol
  del usuario autenticado.
  """

  alias Emergencia.Consola.MenuFamilias
  alias Emergencia.Consola.MenuPersonas
  alias Emergencia.Consola.MenuAlbergues
  alias Emergencia.Consola.MenuAutenticacion
  alias Emergencia.Aplicacion.Autenticacion
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n========================================", :mensaje)
    Util.mostrar("       SISTEMA DE GESTIÓN DE EMERGENCIAS", :mensaje)
    Util.mostrar("========================================", :mensaje)

    Util.mostrar("Usuario: #{sesion.nombre_completo}", :mensaje)
    Util.mostrar("Rol: #{sesion.tipo_usuario}", :mensaje)

    mostrar_opciones(sesion.tipo_usuario)

    opcion = Util.ingresar("\nSeleccione una opción: ", :texto)

    case opcion do
      "1" ->
        MenuPersonas.iniciar(sesion)
        iniciar(sesion)

      "2" ->
        MenuFamilias.iniciar(sesion)
        iniciar(sesion)

      "3" ->
        MenuAlbergues.iniciar(sesion)
        iniciar(sesion)

      "4" ->
        mostrar_modulo_no_disponible("Recursos")
        iniciar(sesion)

      "5" ->
        mostrar_modulo_no_disponible("Mensajes")
        iniciar(sesion)

      "6" ->
        mostrar_modulo_no_disponible("Mascotas")
        iniciar(sesion)

      "7" ->
        mostrar_modulo_no_disponible("Actividades")
        iniciar(sesion)

      "8" ->
        cerrar_sesion(sesion)

      _ ->
        Util.mostrar("\nOpción no válida.", :error)
        iniciar(sesion)
    end
  end

  defp mostrar_opciones(:administrador) do
    mostrar_opciones_generales()
  end

  defp mostrar_opciones(:coordinador) do
    mostrar_opciones_generales()
  end

  defp mostrar_opciones(:voluntario) do
    Util.mostrar("\n========== MÓDULOS DISPONIBLES ==========", :mensaje)
    Util.mostrar("1. Gestión de personas", :mensaje)
    Util.mostrar("2. Gestión de familias", :mensaje)
    Util.mostrar("3. Gestión de albergues", :mensaje)
    Util.mostrar("6. Gestión de mascotas", :mensaje)
    Util.mostrar("8. Cerrar sesión", :mensaje)
  end

  defp mostrar_opciones(:ciudadano) do
    Util.mostrar("\n========== MÓDULOS DISPONIBLES ==========", :mensaje)
    Util.mostrar("1. Consultar y reportar personas", :mensaje)
    Util.mostrar("2. Consultar familias", :mensaje)
    Util.mostrar("6. Reportar mascotas", :mensaje)
    Util.mostrar("8. Cerrar sesión", :mensaje)
  end

  defp mostrar_opciones_generales do
    Util.mostrar("\n========== MÓDULOS DISPONIBLES ==========", :mensaje)
    Util.mostrar("1. Gestión de personas", :mensaje)
    Util.mostrar("2. Gestión de familias", :mensaje)
    Util.mostrar("3. Gestión de albergues", :mensaje)
    Util.mostrar("4. Gestión de recursos", :mensaje)
    Util.mostrar("5. Gestión de mensajes", :mensaje)
    Util.mostrar("6. Gestión de mascotas", :mensaje)
    Util.mostrar("7. Consulta de actividades", :mensaje)
    Util.mostrar("8. Cerrar sesión", :mensaje)
  end

  defp cerrar_sesion(sesion) do
    case MenuAutenticacion.cerrar(sesion) do
      :ok ->
        MenuAutenticacion.mostrar()

      {:error, _motivo} ->
        iniciar(sesion)
    end
  end

  defp mostrar_modulo_no_disponible(nombre) do
    Util.mostrar("\nEl módulo de #{nombre} todavía no está disponible.", :mensaje)
  end
end
