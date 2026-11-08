defmodule Emergencia.Persona do
  alias Emergencia.GeneradorID

  @estados_permitidos [
    :sin_informacion,
    :reportada,
    :localizada,
    :trasladada,
    :en_albergue,
    :reunificada
  ]

  @enforce_keys [:id, :codigo_persona, :nombre, :documento, :id_zona, :estado]
  defstruct [
    :id,
    :codigo_persona,
    :nombre,
    :documento,
    :dato_referencia,
    :edad,
    :id_zona,
    :id_familia,
    :estado,
    historial_estados: []
  ]

  @type estado_persona ::
          :sin_informacion | :reportada | :localizada | :trasladada | :en_albergue | :reunificada
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_persona: String.t(),
          nombre: String.t(),
          documento: String.t(),
          dato_referencia: String.t() | nil,
          edad: non_neg_integer() | nil,
          id_zona: String.t(),
          id_familia: String.t() | nil,
          estado: estado_persona(),
          historial_estados: list()
        }

  def nueva(nombre, codigo, documento, id_zona, estado, opciones \\ []) do
    edad = Keyword.get(opciones, :edad)
    dato_ref = Keyword.get(opciones, :dato_referencia)
    id_fam = Keyword.get(opciones, :id_familia)

    cond do
      is_nil(nombre) or is_nil(documento) or is_nil(id_zona) ->
        {:error, "Nombre, documento y zona son obligatorios"}

      estado not in @estados_permitidos ->
        {:error, "Estado inválido. Opciones: #{inspect(@estados_permitidos)}"}

      not is_nil(edad) and (not is_integer(edad) or edad < 0) ->
        {:error, "La edad debe ser un número entero no negativo"}

      true ->
        historial_inicial = [{estado, DateTime.utc_now()}]

        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_persona: codigo,
           nombre: nombre,
           documento: documento,
           dato_referencia: dato_ref,
           edad: edad,
           id_zona: id_zona,
           id_familia: id_fam,
           estado: estado,
           historial_estados: historial_inicial
         }}
    end
  end

  def cambiar_estado(%__MODULE__{} = persona, nuevo_estado) do
  if nuevo_estado in @estados_permitidos do
    if persona.estado == nuevo_estado do
      {:error, "La persona ya tiene ese estado"}
    else
      historial = [
        {nuevo_estado, DateTime.utc_now()}
        | persona.historial_estados
      ]

      {:ok,
       %{
         persona
         | estado: nuevo_estado,
           historial_estados: historial
       }}
    end
  else
    {:error, "Estado de persona inválido"}
  end
end

  def a_map(%__MODULE__{} = persona) do
    persona
    |> Map.from_struct()
    |> Map.update!(:estado, &Atom.to_string/1)
    |> Map.update!(:historial_estados, fn historial ->
      Enum.map(historial, fn {estado, fecha} ->
        [Atom.to_string(estado), DateTime.to_iso8601(fecha)]
      end)
    end)
    |> Map.new(fn {campo, valor} -> {Atom.to_string(campo), valor} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar(mapa, campos),
         :ok <- validar_ids(attrs),
         {:ok, estado} <- obtener_estado(attrs[:estado]),
         {:ok, historial} <- obtener_historial(attrs[:historial_estados] || []),
         {:ok, persona} <-
           construir(attrs |> Map.put(:estado, estado) |> Map.put(:historial_estados, historial)) do
      {:ok, persona}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de persona inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La persona debe ser un mapa válido"}

  defp normalizar(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      campo = if is_atom(k), do: k, else: Enum.find(campos, &(Atom.to_string(&1) == k))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, v)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(k)}"}}
    end)
  end

  defp validar_ids(attrs) do
    if Enum.all?([attrs[:id], attrs[:codigo_persona]], &(is_binary(&1) and &1 != "")),
      do: :ok,
      else: {:error, "ID y código de persona son obligatorios"}
  end

  defp obtener_estado(estado) when estado in @estados_permitidos, do: {:ok, estado}

  defp obtener_estado(estado) when is_binary(estado) do
    case Enum.find(@estados_permitidos, &(Atom.to_string(&1) == estado)) do
      nil -> {:error, "Estado de persona inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_estado(_), do: {:error, "Estado de persona inválido"}

  defp obtener_historial(historial) when is_list(historial) do
    Enum.reduce_while(historial, {:ok, []}, fn
      [estado, fecha], {:ok, acc} ->
        with {:ok, estado} <- obtener_estado(estado),
             {:ok, fecha} <- obtener_fecha(fecha) do
          {:cont, {:ok, [{estado, fecha} | acc]}}
        else
          error -> {:halt, error}
        end

      {estado, fecha}, {:ok, acc} ->
        with {:ok, estado} <- obtener_estado(estado),
             {:ok, fecha} <- obtener_fecha(fecha) do
          {:cont, {:ok, [{estado, fecha} | acc]}}
        else
          error -> {:halt, error}
        end

      _, _ ->
        {:halt, {:error, "Historial de persona inválido"}}
    end)
    |> case do
      {:ok, registros} -> {:ok, Enum.reverse(registros)}
      error -> error
    end
  end

  defp obtener_historial(_), do: {:error, "Historial de persona inválido"}

  defp obtener_fecha(%DateTime{} = fecha), do: {:ok, fecha}

  defp obtener_fecha(fecha) when is_binary(fecha) do
    case DateTime.from_iso8601(fecha) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "Fecha inválida en historial"}
    end
  end

  defp obtener_fecha(_), do: {:error, "Fecha inválida en historial"}

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de persona: #{Exception.message(error)}"}
  end
end
