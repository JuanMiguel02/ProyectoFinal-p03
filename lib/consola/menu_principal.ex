defmodule Emergencia.Consola.MenuPrincipal do
  @moduledoc """
  Gestiona el menú principal del sistema de emergencias.
  Solo permite ejecutar las opciones que corresponden al rol del usuario.
  """

  alias Emergencia.Consola.MenuFamilias
  alias Emergencia.Consola.MenuPersonas
  alias Emergencia.Consola.MenuAlbergues
  alias Emergencia.Consola.MenuRecursos
  alias Emergencia.Consola.MenuMensajes
  alias Emergencia.Consola.MenuMascotas
  alias Emergencia.Consola.MenuTerritorio
  alias Emergencia.Consola.MenuAutenticacion
  alias Util

  # Opciones que cada rol puede ejecutar (debe coincidir con lo que se muestra)
  @opciones_por_rol %{
    ciudadano: ["1", "2", "4", "5", "6", "9", "10", "8"],
    voluntario: ["1", "2", "3", "4", "5", "6", "9", "10", "8"],
    coordinador: ["1", "2", "3", "4", "5", "6", "7", "9", "10", "8"],
    administrador: ["1", "2", "3", "4", "5", "6", "7", "9", "10", "8"]
  }

  def iniciar(sesion) do
    Util.mostrar("\n========================================", :mensaje)
    Util.mostrar("       SISTEMA DE GESTIÓN DE EMERGENCIAS", :mensaje)
    Util.mostrar("========================================", :mensaje)

    Util.mostrar("Usuario: #{sesion.nombre_completo}", :mensaje)
    Util.mostrar("Rol: #{sesion.tipo_usuario}", :mensaje)

    mostrar_opciones(sesion.tipo_usuario)

    opcion = Util.ingresar("\nSeleccione una opción: ", :texto)

    if opcion in Map.get(@opciones_por_rol, sesion.tipo_usuario, []) do
      ejecutar(opcion, sesion)
    else
      Util.mostrar("\nOpción no válida o sin permisos.", :error)
      iniciar(sesion)
    end
  end

  # ============================================================
  # EJECUCIÓN DE OPCIONES
  # ============================================================

  defp ejecutar("1", sesion) do
    MenuPersonas.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("2", sesion) do
    MenuFamilias.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("3", sesion) do
    MenuAlbergues.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("4", sesion) do
    MenuRecursos.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("5", sesion) do
    MenuMensajes.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("6", sesion) do
    MenuMascotas.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("7", sesion) do
    with {:ok, actividades} <- Emergencia.Aplicacion.GestionActividades.listar(sesion) do
      Util.mostrar("\n--- ACTIVIDADES RECIENTES ---", :mensaje)

      actividades
      |> Enum.take(10)
      |> Enum.each(fn a ->
        Util.mostrar("[#{a.fecha}] #{a.descripcion}", :mensaje)
      end)
    else
      {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
    end

    iniciar(sesion)
  end

  defp ejecutar("8", sesion), do: cerrar_sesion(sesion)

  defp ejecutar("9", sesion) do
    MenuTerritorio.iniciar(sesion)
    iniciar(sesion)
  end

  defp ejecutar("10", sesion) do
    mostrar_resumen(sesion)
    iniciar(sesion)
  end

  # ============================================================
  # OPCIONES VISIBLES SEGÚN ROL
  # ============================================================

  defp mostrar_opciones(:administrador), do: mostrar_opciones_generales()
  defp mostrar_opciones(:coordinador), do: mostrar_opciones_generales()

  defp mostrar_opciones(:voluntario) do
    Util.mostrar("\n========== MÓDULOS DISPONIBLES ==========", :mensaje)
    Util.mostrar("1. Gestión de personas", :mensaje)
    Util.mostrar("2. Gestión de familias", :mensaje)
    Util.mostrar("3. Gestión de albergues", :mensaje)
    Util.mostrar("4. Gestión de recursos y necesidades", :mensaje)
    Util.mostrar("5. Gestión de mensajes", :mensaje)
    Util.mostrar("6. Gestión de mascotas", :mensaje)
    Util.mostrar("9. Gestión del territorio", :mensaje)
    Util.mostrar("10. Resumen general", :mensaje)
    Util.mostrar("8. Cerrar sesión", :mensaje)
  end

  defp mostrar_opciones(:ciudadano) do
    Util.mostrar("\n========== MÓDULOS DISPONIBLES ==========", :mensaje)
    Util.mostrar("1. Consultar y reportar personas", :mensaje)
    Util.mostrar("2. Consultar familias", :mensaje)
    Util.mostrar("4. Gestión de recursos y necesidades", :mensaje)
    Util.mostrar("5. Enviar mensajes", :mensaje)
    Util.mostrar("6. Reportar mascotas", :mensaje)
    Util.mostrar("9. Gestión del territorio", :mensaje)
    Util.mostrar("10. Resumen general", :mensaje)
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
    Util.mostrar("9. Gestión del territorio", :mensaje)
    Util.mostrar("10. Resumen general", :mensaje)
    Util.mostrar("8. Cerrar sesión", :mensaje)
  end

  defp mostrar_resumen(sesion) do
    case Emergencia.Aplicacion.GestionResumen.resumen_global(sesion) do
      {:ok, resumen} ->
        Util.mostrar("\n========== RESUMEN GENERAL ==========", :mensaje)

        Enum.each(resumen, fn {campo, valor} ->
          Util.mostrar("#{campo}: #{valor}", :mensaje)
        end)

      {:error, motivo} ->
        Util.mostrar("No se pudo consultar el resumen: #{inspect(motivo)}", :error)
    end
  end

  defp cerrar_sesion(sesion) do
    case MenuAutenticacion.cerrar(sesion) do
      :ok ->
        MenuAutenticacion.mostrar()

      {:error, motivo} ->
        Util.mostrar("\nNo se pudo cerrar la sesión: #{inspect(motivo)}", :error)
        iniciar(sesion)
    end
  end
end
