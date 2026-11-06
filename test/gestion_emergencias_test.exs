defmodule GestionEmergenciasTest do
  use ExUnit.Case
  doctest GestionEmergencias

  test "greets the world" do
    assert GestionEmergencias.hello() == :world
  end

  test "all entity constructors generate their own UUID" do
    entities = [
      {Emergencia.Actividad.nueva("desc", "test", "user"), :id},
      {Emergencia.Albergue.nueva("local", "Albergue", "zona", 20), :id},
      {Emergencia.AsignacionRecurso.nueva("necesidad", "inventario", 1), :id},
      {Emergencia.CentroAcopio.nueva("Centro", "Dirección", 10, "zona"), :id},
      {Emergencia.CoincidenciaMascota.nueva("perdida", "encontrada"), :id},
      {Emergencia.Familia.nueva("Familia"), :id},
      {Emergencia.InventarioUbicacion.nueva("ubicacion", :albergue, "recurso", 1), :id},
      {Emergencia.Mensaje.nuevo("remitente", "contenido"), :id_envio},
      {Emergencia.MensajeDestinatario.nuevo("envio", "persona"), :id_mensaje_destinatario},
      {Emergencia.MovimientoRecurso.nueva(1, :ingreso, id_inventario_destino: "inventario"), :id},
      {Emergencia.Necesidad.nueva(:agua, 1, "zona", :alta), :id},
      {Emergencia.Persona.nueva("Persona", "documento", "zona", :reportada), :id},
      {Emergencia.PuntoAtencion.nueva("Punto", :medico, "ubicación"), :id},
      {Emergencia.Recurso.nueva("agua", "Agua", :otro, "litro"), :id},
      {Emergencia.RegistroAlbergue.nueva("albergue", "persona", :ingreso), :id},
      {Emergencia.ReporteMascota.nueva(:perdida, "Perro", "negro", :pequeno, "zona", "usuario"),
       :id},
      {Emergencia.Sector.nueva("Sector", :bajo, 1), :id},
      {Emergencia.Usuario.nuevo("usuario", "clave", "Nombre", :voluntario), :id_usuario},
      {Emergencia.Zona.nueva("Zona", :medio, 1), :id}
    ]

    ids =
      Enum.map(entities, fn {{:ok, entity}, id_field} ->
        id = Map.fetch!(entity, id_field)
        assert Regex.match?(uuid_v4_regex(), id)
        id
      end)

    assert length(Enum.uniq(ids)) == length(ids)
  end

  defp uuid_v4_regex do
    ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  end
end
