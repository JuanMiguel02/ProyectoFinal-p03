defmodule Emergencia.GeneradorID do
  @moduledoc """
  Genera UUID internos y códigos públicos consecutivos
  a partir de las colecciones existentes.
  """

  @doc """
  Genera el siguiente código disponible de una colección.

  Recibe:
  - prefijo: prefijo del código, por ejemplo "USR".
  - registros: mapa que contiene las entidades existentes.
  - obtener_codigo: función que extrae el código de cada entidad.

  Ejemplo:
      GeneradorID.generar("USR", usuarios, & &1.codigo_usuario)
  """
  def generar(prefijo, registros, obtener_codigo)
      when is_map(registros) and is_function(obtener_codigo, 1) do
    prefijo = normalizar_prefijo(prefijo)

    mayor_numero =
      registros
      |> Map.values()
      |> Enum.reduce(0, fn registro, mayor ->
        codigo = obtener_codigo.(registro)

        case extraer_numero(codigo, prefijo) do
          {:ok, numero} -> max(numero, mayor)
          :error -> mayor
        end
      end)

    generar(prefijo, mayor_numero + 1)
  end

  @doc """
  Formatea un número con al menos cuatro dígitos.
  """
  def generar(prefijo, numero)
      when is_integer(numero) and numero > 0 do
    "#{normalizar_prefijo(prefijo)}-#{String.pad_leading(Integer.to_string(numero), 4, "0")}"
  end

  @doc """
  Genera un UUID versión 4.
  """
  def generar_uuid do
    <<a::32, b::16, _::4, c::12, _::2, d::14, e::48>> =
      :crypto.strong_rand_bytes(16)

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

  # Extrae el número únicamente si el código pertenece
  # al prefijo solicitado y tiene un formato válido.
  defp extraer_numero(codigo, prefijo) when is_binary(codigo) do
    inicio = prefijo <> "-"

    if String.starts_with?(codigo, inicio) do
      numero_texto = String.replace_prefix(codigo, inicio, "")

      case Integer.parse(numero_texto) do
        {numero, ""} when numero > 0 -> {:ok, numero}
        _ -> :error
      end
    else
      :error
    end
  end

  defp extraer_numero(_, _), do: :error

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

  defdelegate generar(prefijo, registros, obtener_codigo),
    to: Emergencia.GeneradorID

  defdelegate generar(prefijo, numero),
    to: Emergencia.GeneradorID

  defdelegate generar_uuid(),
    to: Emergencia.GeneradorID
end
