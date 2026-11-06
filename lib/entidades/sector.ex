defmodule Emergencia.Sector do
  alias Emergencia.GeneradorID

  @niveles_permitidos [:bajo, :medio, :alto, :critico]

  @enforce_keys [:id, :codigo_sector, :nombre, :nivel_afectacion, :personas_afectadas]
  defstruct [
    :id,
    :codigo_sector,
    :nombre,
    :nivel_afectacion,
    :personas_afectadas,
    puntos_atencion: []
  ]

  @type nivel_afectacion :: :bajo | :medio | :alto | :critico
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_sector: String.t(),
          nombre: String.t(),
          nivel_afectacion: nivel_afectacion(),
          personas_afectadas: non_neg_integer(),
          puntos_atencion: list()
        }

  def nuevo(nombre, nivel, personas) do
    cond do
      is_nil(nombre) ->
        {:error, "El nombre es obligatorio"}

      nivel not in @niveles_permitidos ->
        {:error, "Nivel de afectación :#{nivel} inválido"}

      personas < 0 ->
        {:error, "La cantidad de personas afectadas no puede ser negativa"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_sector: GeneradorID.generar("SEC"),
           nombre: nombre,
           nivel_afectacion: nivel,
           personas_afectadas: personas,
           puntos_atencion: []
         }}
    end
  end

  def a_map(%__MODULE__{} = sector) do
    sector
    |> Map.from_struct()
    |> Map.update!(:nivel_afectacion, &Atom.to_string/1)
    |> Map.update!(:puntos_atencion, fn puntos ->
      Enum.map(puntos, fn
        %Emergencia.PuntoAtencion{} = punto -> Emergencia.PuntoAtencion.a_map(punto)
        punto -> punto
      end)
    end)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar_campos(mapa, campos),
         {:ok, nivel} <- obtener_nivel(attrs[:nivel_afectacion]),
         :ok <- validar_ids(attrs),
         {:ok, puntos} <- reconstruir_puntos(attrs[:puntos_atencion] || []),
         {:ok, sector} <-
           construir(
             attrs
             |> Map.put(:nivel_afectacion, nivel)
             |> Map.put(:puntos_atencion, puntos)
           ) do
      {:ok, sector}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de sector inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "El sector debe ser un mapa válido"}

  defp normalizar_campos(mapa, campos) do
    Enum.reduce_while(mapa, {:ok, %{}}, fn {clave, valor}, {:ok, acc} ->
      campo =
        if is_atom(clave), do: clave, else: Enum.find(campos, &(Atom.to_string(&1) == clave))

      if campo in campos and not Map.has_key?(acc, campo),
        do: {:cont, {:ok, Map.put(acc, campo, valor)}},
        else: {:halt, {:error, "Campo desconocido o duplicado: #{inspect(clave)}"}}
    end)
  end

  defp obtener_nivel(nivel) when nivel in @niveles_permitidos, do: {:ok, nivel}

  defp obtener_nivel(nivel) when is_binary(nivel) do
    case Enum.find(@niveles_permitidos, &(Atom.to_string(&1) == nivel)) do
      nil -> {:error, "Nivel de afectación inválido"}
      valor -> {:ok, valor}
    end
  end

  defp obtener_nivel(_), do: {:error, "Nivel de afectación inválido"}

  defp validar_ids(attrs) do
    if Enum.all?([attrs[:id], attrs[:codigo_sector]], &(is_binary(&1) and &1 != "")),
      do: :ok,
      else: {:error, "ID y código de sector son obligatorios"}
  end

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de sector: #{Exception.message(error)}"}
  end

  defp reconstruir_puntos(puntos) when is_list(puntos) do
    Enum.reduce_while(puntos, {:ok, []}, fn
      %Emergencia.PuntoAtencion{} = punto, {:ok, acc} ->
        {:cont, {:ok, [punto | acc]}}

      mapa, {:ok, acc} when is_map(mapa) ->
        case Emergencia.PuntoAtencion.desde_map(mapa) do
          {:ok, punto} -> {:cont, {:ok, [punto | acc]}}
          {:error, motivo} -> {:halt, {:error, motivo}}
        end

      _, _ ->
        {:halt, {:error, "Punto de atención inválido en sector"}}
    end)
    |> case do
      {:ok, valores} -> {:ok, Enum.reverse(valores)}
      error -> error
    end
  end

  defp reconstruir_puntos(_), do: {:error, "La lista de puntos de atención no es válida"}
end
