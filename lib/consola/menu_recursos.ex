defmodule Emergencia.Consola.MenuRecursos do
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.RecursosServidor

  def iniciar(sesion) do
    Util.mostrar("\n--- GESTIÓN DE RECURSOS ---", :mensaje)
    Util.mostrar("1. Listar Inventarios Disponibles", :mensaje)
    Util.mostrar("2. Listar Necesidades Registradas", :mensaje)
    Util.mostrar("3. Volver al menú principal", :mensaje)

    case Util.ingresar("Seleccione una opción: ", :texto) do
      "1" ->
        with :ok <- Autenticacion.autorizar(sesion, :consultar_recursos),
             {:ok, inventarios} <- RecursosServidor.listar_inventarios() do
          Enum.each(inventarios, fn i ->
            Util.mostrar(
              " - [ID: #{i.id}] Ubicación: #{i.id_ubicacion} | Recurso: #{i.id_recurso} | Disp: #{i.cantidad_disponible}",
              :mensaje
            )
          end)
        else
          {:error, motivo} -> Util.mostrar("\n#{inspect(motivo)}", :error)
        end

        iniciar(sesion)

      "2" ->
        with :ok <- Autenticacion.autorizar(sesion, :consultar_necesidades),
             {:ok, necesidades} <- RecursosServidor.listar_necesidades() do
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
