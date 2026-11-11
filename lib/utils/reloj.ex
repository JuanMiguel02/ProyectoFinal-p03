defmodule Emergencia.Reloj do
  @moduledoc """
  Provee la fecha y hora actual según la zona horaria configurada en la máquina.
  """

  def ahora_local do
    tiempo_microsegundos = System.os_time(:microsecond)
    tiempo_segundos = div(tiempo_microsegundos, 1_000_000)
    microsegundos = rem(tiempo_microsegundos, 1_000_000)

    fecha_hora_local = :calendar.system_time_to_local_time(tiempo_segundos, :second)
    fecha_hora_utc = :calendar.system_time_to_universal_time(tiempo_segundos, :second)

    segundos_desfase =
      :calendar.datetime_to_gregorian_seconds(fecha_hora_local) -
        :calendar.datetime_to_gregorian_seconds(fecha_hora_utc)

    {{anio, mes, dia}, {hora, minuto, segundo}} = fecha_hora_local

    {:ok, fecha_local} =
      NaiveDateTime.new(
        anio,
        mes,
        dia,
        hora,
        minuto,
        segundo,
        {microsegundos, 6}
      )

    fecha_base = DateTime.from_naive!(fecha_local, "Etc/UTC")

    %{
      fecha_base
      | time_zone: "Etc/Local",
        zone_abbr: "LOCAL",
        utc_offset: segundos_desfase,
        std_offset: 0
    }
  end
end
