defmodule Emergencia.Consola.MenuRecursos do
  alias Emergencia.Aplicacion.GestionRecursos
  alias Util

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE RECURSOS ---", :mensaje)
    Util.mostrar("1. Listar Inventarios Disponibles", :mensaje)
    Util.mostrar("2. Listar Necesidades Registradas", :mensaje)
    Util.mostrar("3. Registrar Recurso", :mensaje)
    Util.mostrar("4. Agregar Inventario", :mensaje)
    Util.mostrar("5. Asignar Recurso", :mensaje)
    Util.mostrar("6. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        case GestionRecursos.listar_inventarios(sesion) do
          {:ok, inventarios} ->
            Enum.each(inventarios, fn i ->
              Util.mostrar(" - [ID: #{i.id}] Ubicación: #{i.id_ubicacion} | Recurso: #{i.id_recurso} | Disp: #{i.cantidad_disponible}", :mensaje)
            end)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "2" ->
        case GestionRecursos.listar_necesidades(sesion) do
          {:ok, necesidades} ->
            Enum.each(necesidades, fn n ->
              Util.mostrar(" - [#{n.codigo_necesidad}] Tipo: #{n.tipo} | Req: #{n.cantidad_requerida} | Pendiente: #{n.cantidad_pendiente} | Estado: #{n.estado}", :mensaje)
            end)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "3" ->
        nombre = Util.ingresar("Nombre del recurso: ", :texto)
        cat = Util.ingresar("Categoría (ej. alimento, agua, medicina): ", :texto)
        unidad = Util.ingresar("Unidad de medida: ", :texto)
        case GestionRecursos.registrar_recurso(sesion, nombre, String.to_atom(cat), unidad) do
          {:ok, r} -> Util.mostrar("Recurso registrado [Código: #{r.codigo_recurso}]", :mensaje)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "4" ->
        ub_cod = Util.ingresar("Código/ID de ubicación: ", :texto)
        tipo_ub = Util.ingresar("Tipo de ubicación (albergue/centro_acopio): ", :texto)
        rec_cod = Util.ingresar("Código/ID de recurso: ", :texto)
        cant = Util.ingresar("Cantidad: ", :entero)
        case GestionRecursos.agregar_inventario(sesion, ub_cod, String.to_atom(tipo_ub), rec_cod, cant) do
          {:ok, inv} -> Util.mostrar("Inventario agregado [ID: #{inv.id}]", :mensaje)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "5" ->
        nec_cod = Util.ingresar("Código de necesidad: ", :texto)
        inv_id = Util.ingresar("ID de inventario: ", :texto)
        cant = Util.ingresar("Cantidad a asignar: ", :entero)
        case GestionRecursos.asignar_recurso(sesion, nec_cod, inv_id, cant) do
          {:ok, asig} -> Util.mostrar("Recurso asignado [ID: #{asig.id}]", :mensaje)
          {:error, msg} -> Util.mostrar("Error: #{inspect(msg)}", :error)
        end
        iniciar(sesion)

      "6" -> :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
