defmodule Emergencia.Zona do
  alias Emergencia.GeneradorID

  @niveles_permitidos [:bajo, :medio, :alto, :critico]

  @enforce_keys [:id, :codigo_zona, :nombre, :nivel_afectacion, :personas_estimadas]
  defstruct [:id, :codigo_zona, :nombre, :nivel_afectacion, :personas_estimadas, sectores: []]

  @type nivel_afectacion :: :bajo | :medio | :alto | :critico
  @type t :: %__MODULE__{
          id: String.t(),
          codigo_zona: String.t(),
          nombre: String.t(),
          nivel_afectacion: nivel_afectacion(),
          personas_estimadas: non_neg_integer(),
          sectores: list()
        }

  def nueva(nombre, nivel, personas, codigo_zona) do
    cond do
      not is_binary(nombre) or String.trim(nombre) == "" ->
        {:error, "El nombre es obligatorio"}

      nivel not in @niveles_permitidos ->
        {:error, "Nivel de afectación :#{nivel} inválido"}

      not is_integer(personas) or personas < 0 ->
        {:error, "Las personas estimadas no pueden ser negativas"}

      not is_binary(codigo_zona) or String.trim(codigo_zona) == "" ->
        {:error, "El código de zona es obligatorio"}

      true ->
        {:ok,
         %__MODULE__{
           id: GeneradorID.generar_uuid(),
           codigo_zona: codigo_zona,
           nombre: nombre,
           nivel_afectacion: nivel,
           personas_estimadas: personas,
           sectores: []
         }}
    end
  end

  def a_map(%__MODULE__{} = zona) do
    zona
    |> Map.from_struct()
    |> Map.update!(:nivel_afectacion, &Atom.to_string/1)
    |> Map.update!(:sectores, fn sectores ->
      Enum.map(sectores, fn
        %Emergencia.Sector{} = sector -> Emergencia.Sector.a_map(sector)
        sector -> sector
      end)
    end)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def desde_map(mapa) when is_map(mapa) do
    campos = Map.keys(__MODULE__.__struct__()) -- [:__struct__]

    with {:ok, attrs} <- normalizar_campos(mapa, campos),
         {:ok, nivel} <- obtener_nivel(attrs[:nivel_afectacion]),
         :ok <- validar_ids(attrs),
         {:ok, sectores} <- reconstruir_sectores(attrs[:sectores] || []),
         {:ok, zona} <-
           construir(attrs |> Map.put(:nivel_afectacion, nivel) |> Map.put(:sectores, sectores)) do
      {:ok, zona}
    end
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Mapa de zona inválido: #{Exception.message(error)}"}
  end

  def desde_map(_), do: {:error, "La zona debe ser un mapa válido"}

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
    if Enum.all?([attrs[:id], attrs[:codigo_zona]], &(is_binary(&1) and &1 != "")),
      do: :ok,
      else: {:error, "ID y código de zona son obligatorios"}
  end

  defp construir(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  rescue
    error in [ArgumentError, KeyError] ->
      {:error, "Faltan campos de zona: #{Exception.message(error)}"}
  end

  defp reconstruir_sectores(sectores) when is_list(sectores) do
    Enum.reduce_while(sectores, {:ok, []}, fn
      %Emergencia.Sector{} = sector, {:ok, acc} ->
        {:cont, {:ok, [sector | acc]}}

      mapa, {:ok, acc} when is_map(mapa) ->
        case Emergencia.Sector.desde_map(mapa) do
          {:ok, sector} -> {:cont, {:ok, [sector | acc]}}
          {:error, motivo} -> {:halt, {:error, motivo}}
        end

      _, _ ->
        {:halt, {:error, "Sector inválido en zona"}}
    end)
    |> case do
      {:ok, valores} -> {:ok, Enum.reverse(valores)}
      error -> error
    end
  end

  defp reconstruir_sectores(_), do: {:error, "La lista de sectores no es válida"}
end
