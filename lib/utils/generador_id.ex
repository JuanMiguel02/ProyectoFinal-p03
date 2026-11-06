defmodule Emergencia.GeneradorID do
  @moduledoc """
  Genera UUID internos y códigos públicos consecutivos durante la ejecución actual.
  """

  @doc "Genera el siguiente código público en el nodo actual."
  def generar(prefijo) do
    numero = System.unique_integer([:positive, :monotonic])
    generar(prefijo, numero)
  end

  @doc "Formatea un número con al menos cuatro dígitos."
  def generar(prefijo, numero) when is_integer(numero) and numero >= 0 do
    "#{normalizar_prefijo(prefijo)}-#{String.pad_leading(Integer.to_string(numero), 4, "0")}"
  end

  @doc "Genera un UUID versión 4."
  def generar_uuid do
    <<a::32, b::16, _::4, c::12, _::2, d::14, e::48>> = :crypto.strong_rand_bytes(16)
    c = 0x4000 + c
    d = 0x8000 + d

    Enum.join(
      [
        hex(a, 8),
        hex(b, 4),
        hex(c, 4),
        hex(d, 4),
        hex(e, 12)
      ],
      "-"
    )
  end

  defp normalizar_prefijo(prefijo) do
    prefijo =
      prefijo
      |> to_string()
      |> String.trim()
      |> String.upcase()

    if prefijo == "" do
      raise ArgumentError, "El prefijo del código no puede estar vacío"
    end

    prefijo
  end

  defp hex(valor, ancho) do
    valor
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(ancho, "0")
  end
end

defmodule Emergencia.Utils.GeneradorID do
  @moduledoc false

  defdelegate generar(prefijo), to: Emergencia.GeneradorID
  defdelegate generar(prefijo, numero), to: Emergencia.GeneradorID
  defdelegate generar_uuid(), to: Emergencia.GeneradorID
end
