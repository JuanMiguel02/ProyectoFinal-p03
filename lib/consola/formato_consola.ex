defmodule Emergencia.Consola.FormatoConsola do
  @moduledoc false

  def fecha_hora(nil), do: "Sin fecha"

  def fecha_hora(%DateTime{} = fecha) do
    fecha_local =
      if fecha.utc_offset == 0 and fecha.std_offset == 0 do
        unix_segundos = DateTime.to_unix(fecha)
        microsegundos = elem(fecha.microsecond, 0)

        {{anio, mes, dia}, {hora, minuto, segundo}} =
          :calendar.system_time_to_local_time(unix_segundos, :second)

        NaiveDateTime.new!(anio, mes, dia, hora, minuto, segundo, {microsegundos, 6})
      else
        DateTime.to_naive(fecha)
      end

    Calendar.strftime(fecha_local, "%d/%m/%Y %H:%M:%S")
  end

  def estado(:sin_informacion), do: "Sin información"
  def estado(:en_albergue), do: "En albergue"
  def estado(:en_atencion), do: "En atención"
  def estado(:critica), do: "Crítica"
  def estado(:critico), do: "Crítico"
  def estado(:atendida), do: "Atendida"
  def estado(:pendiente), do: "Pendiente"
  def estado(:entregado), do: "Entregado"
  def estado(:asignada), do: "Asignada"
  def estado(:cancelada), do: "Cancelada"
  def estado(:reunificada), do: "Reunificada"
  def estado(:reportada), do: "Reportada"
  def estado(:localizada), do: "Localizada"
  def estado(:trasladada), do: "Trasladada"
  def estado(:activa), do: "Activa"
  def estado(:resuelta), do: "Resuelta"
  def estado(:posible_coincidencia), do: "Posible coincidencia"
  def estado(:perdida), do: "Perdida"
  def estado(:encontrada), do: "Encontrada"
  def estado(:confirmada), do: "Confirmada"
  def estado(:rechazada), do: "Rechazada"

  def estado(valor) when is_atom(valor) do
    valor
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def estado(valor), do: to_string(valor)
end
