defmodule Emergencia.ServicioUsuarioTest do
  use ExUnit.Case

  alias Emergencia.EstadoUsuarios
  # <--- Asegúrate que sea ServicioUsuario (con 'c')
  alias Emergencia.Servicios.ServicioUsuario

  test "permite registrar y autenticar un usuario exitosamente" do
    estado_inicial = %EstadoUsuarios{usuarios: %{}, sesiones: %{}}

    {:ok, usuario, estado_con_usuario} =
      ServicioUsuario.registrar(
        estado_inicial,
        "carlos99",
        "secreto123",
        "Carlos Gomez",
        :ciudadano
      )

    assert usuario.nombre_usuario == "carlos99"
    assert usuario.tipo_usuario == :ciudadano

    {:ok, _usuario_conectado, _estado_final} =
      ServicioUsuario.autenticar(
        estado_con_usuario,
        "carlos99",
        "secreto123"
      )
  end

  test "rechaza credenciales inválidas" do
    estado_inicial = %EstadoUsuarios{usuarios: %{}, sesiones: %{}}
    resultado = ServicioUsuario.autenticar(estado_inicial, "no_existo", "badpass")

    assert {:error, "Credenciales inválidas"} = resultado
  end
end
