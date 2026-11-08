defmodule Emergencia.Consola do
  alias Emergencia.Consola.MenuAutenticacion
  alias Util

  def iniciar do
    Util.mostrar("\n========================================", :mensaje)
    Util.mostrar("     SISTEMA DE GESTIÓN DE EMERGENCIAS", :mensaje)
    Util.mostrar("========================================", :mensaje)

    MenuAutenticacion.mostrar()
  end
end
