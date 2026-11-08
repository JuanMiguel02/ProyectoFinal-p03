# Juan Miguel Henao Gaviria
# Valeria Zapata Giraldo
defmodule Util do
  @moduledoc """
  Módulo con utilidades reutilizables

  Centraliza tareas de entrada/salida del usuario, formateo de valores,
  transformación de colecciones y operaciones pequeñas de apoyo para el resto
  del sistema. Su objetivo es mantener la lógica de negocio más limpia y
  evitar duplicación de código entre los módulos del proyecto.
  """

  @doc """
  Muestra un mensaje en la salida estándar o de errores según el tipo indicado.

  ## Parámetros

    - `mensaje`: texto a imprimir.
    - `:mensaje` o `:error`: indica si debe mostrarse en consola normal o en
      error estándar.
  """
  def mostrar(mensaje, :mensaje) do
    mensaje
    |> IO.puts()
  end

  def mostrar(mensaje, :error) do
    IO.puts(:standard_error, mensaje)
  end

  @doc """
  Lee una cadena de texto desde la entrada del usuario y elimina espacios
  sobrantes al inicio y al final.

  Las variantes con tipos específicos (`:entero`, `:real`, `:booleano`, etc.)
  reutilizan esta función para leer la entrada base y convertir el valor.
  """
  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  def ingresar(mensaje, :entero) do
    ingresar(mensaje, &Integer.parse/1, :entero)
  end

  def ingresar(mensaje, :real) do
    ingresar(mensaje, &Float.parse/1, :real)
  end

  def ingresar(mensaje, :booleano) do
    ingresar(
      mensaje,
      fn texto ->
        case String.downcase(texto) do
          "s" -> {true, ""}
          "n" -> {false, ""}
          _ -> :error
        end
      end,
      :booleano
    )
  end

  def ingresar(mensaje, :coleccion_enteros) do
    ingresar(fn -> ingresar(mensaje, :entero) end, :coleccion)
  end

  def ingresar(mensaje, :coleccion_reales) do
    ingresar(fn -> ingresar(mensaje, :real) end, :coleccion)
  end

  def ingresar(mensaje, :coleccion_textos) do
    ingresar(fn -> ingresar(mensaje, :texto) end, :coleccion)
  end

  def ingresar(ingresar_elemento, :coleccion) do
    ingresar_coleccion(ingresar_elemento, [])
  end

  @doc """
  Aplica un formato a cada elemento de una colección y devuelve la lista de
  cadenas resultantes.

  ## Ejemplo

      Util.convertir_coleccion_mensaje([1, 2, 3])

  """
  def convertir_coleccion_mensaje(coleccion, formato \\ fn elemento -> " - #{elemento}\n" end) do
    Enum.map(coleccion, formato)
  end

  @doc """
  Formatea un valor monetario con separadores de miles y dos decimales.

  Ejemplo: `Util.formatear_dinero(4913420)` retorna `"4.913.420.00"`.
  """
  def formatear_dinero(valor) when is_number(valor) do
    str = :erlang.float_to_binary(valor * 1.0, decimals: 2)
    [entera, decimal] = String.split(str, ".")
    "#{formatear_numero(entera)},#{decimal}"
  end

  def formatear_dinero(valor), do: to_string(valor)

  @doc """
  Agrega separadores de miles a un número o texto numérico.

  Utiliza el punto como separador de miles.
  """
  def formatear_numero(valor) when is_number(valor) or is_binary(valor) do
    valor
    |> to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ".")
  end

  @doc """
  Ordena una colección según un criterio especificado.

  ## Parámetros

    - `coleccion`: lista o enumerable a ordenar.
    - `sentido`: `:asc` o `:desc`.
    - `obtener_campo`: función que define el valor de orden.
  """
  def ordenar_coleccion(coleccion, sentido \\ :asc, obtener_campo \\ & &1) do
    Enum.sort_by(coleccion, obtener_campo, sentido)
  end

  @doc """
  Filtra los elementos de una lista cuyo texto tiene una longitud menor o igual
  a la indicada.
  """
  def aplicar_filtro_longitud(coleccion, longitud) do
    Enum.filter(coleccion, &(String.length(&1) <= longitud))
  end

  @doc """
  Filtra los elementos de una lista cuyo texto comienza con el prefijo dado.
  """
  def aplicar_filtro_inicial(coleccion, inicio) do
    Enum.filter(coleccion, &String.starts_with?(&1, inicio))
  end

  defp ingresar(mensaje, funcion, tipo_dato) do
    valor =
      mensaje
      |> ingresar(:texto)
      |> funcion.()

    case valor do
      {numero, _} ->
        numero

      :error ->
        mostrar("Error, tipo de dato inválido para: #{tipo_dato} ", :error)
        ingresar(mensaje, funcion, tipo_dato)
    end
  end

  defp ingresar_coleccion(ingresar_elemento, coleccion_actual) do
    elemento = ingresar_elemento.()

    nueva_coleccion = [elemento | coleccion_actual]

    case ingresar("\n ¿Hay más datos (s/n)?", :booleano) do
      true -> ingresar_coleccion(ingresar_elemento, nueva_coleccion)
      false -> Enum.reverse(nueva_coleccion)
    end
  end
end
