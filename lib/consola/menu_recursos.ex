defmodule Emergencia.Consola.MenuRecursos do
  alias Emergencia.Aplicacion.GestionRecursos

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE RECURSOS ---", :mensaje)
    Util.mostrar("1. Listar Recursos Disponibles", :mensaje)
    Util.mostrar("2. Listar Necesidades Registradas", :mensaje)
    Util.mostrar("3. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        with {:ok, existencias} <- GestionRecursos.listar_recursos(sesion) do
          Enum.each(existencias, fn recurso ->
            Util.mostrar(
              " - Código: #{recurso.codigo} | Ubicación: #{recurso.ubicacion} | Recurso: #{recurso.nombre} | Disp: #{recurso.cantidad} #{recurso.unidad_medida}",
              :mensaje
            )
          end)
        else
          {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "2" ->
        with {:ok, necesidades} <- GestionRecursos.listar_necesidades(sesion) do
          Enum.each(necesidades, fn n ->
            Util.mostrar(
              " - [#{n.codigo_necesidad}] Tipo: #{n.tipo} | Req: #{n.cantidad_requerida} | Pendiente: #{n.cantidad_pendiente} | Estado: #{n.estado}",
              :mensaje
            )
          end)
        else
          {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "3" ->
        :ok

      _ ->
        Util.mostrar("Opción no válida", :error)
        iniciar(sesion)
    end
  end
end
