defmodule Emergencia.GestorDatos do
  alias Emergencia.Almacenamiento.JSON

  alias Emergencia.{
    Usuario,
    Persona,
    Familia,
    Zona,
    Sector,
    CentroAcopio,
    InventarioUbicacion,
    Albergue,
    RegistroAlbergue,
    Necesidad,
    Recurso,
    Mensaje,
    MensajeDestinatario,
    Actividad,
    ReporteMascota,
    CoincidenciaMascota,
    MovimientoRecurso,
    AsignacionRecurso
  }

  # Colecciones que se guardan y cargan.
  # Formato: {clave_estado, archivo, modulo, campo_id}
  @colecciones [
    {:usuarios, "usuarios.json", Usuario, :id},
    {:personas, "personas.json", Persona, :id},
    {:familias, "familias.json", Familia, :id},
    {:zonas, "zonas.json", Zona, :id},
    {:sectores, "sectores.json", Sector, :id},
    {:albergues, "albergues.json", Albergue, :id},
    {:registros_albergues, "registros_albergues.json", RegistroAlbergue, :id},
    {:centros_acopio, "centros_acopio.json", CentroAcopio, :id},
    {:inventarios, "inventarios.json", InventarioUbicacion, :id},
    {:necesidades, "necesidades.json", Necesidad, :id},
    {:recursos, "recursos.json", Recurso, :id},
    {:mensajes, "mensajes.json", Mensaje, :id_envio},
    {:mensajes_destinatarios, "mensajes_destinatarios.json",
     MensajeDestinatario, :id_mensaje_destinatario},
    {:actividades, "actividades.json", Actividad, :id},
    {:reportes_mascotas, "reportes_mascotas.json", ReporteMascota, :id},
    {:coincidencias_mascotas, "coincidencias_mascotas.json",
     CoincidenciaMascota, :id},
    {:movimientos_recursos, "movimientos_recursos.json",
     MovimientoRecurso, :id},
    {:asignaciones_recursos, "asignaciones_recursos.json",
     AsignacionRecurso, :id}
  ]

  @dominios %{
  usuarios: [:usuarios],
  territorio: [:zonas, :sectores, :centros_acopio],
  poblacion: [:personas, :familias, :albergues, :registros_albergues],
  recursos: [
    :recursos,
    :inventarios,
    :necesidades,
    :movimientos_recursos,
    :asignaciones_recursos
  ],
  mensajes: [:mensajes, :mensajes_destinatarios],
  mascotas: [:reportes_mascotas, :coincidencias_mascotas],
  actividades: [:actividades]
}

def cargar_dominio(dominio) do
  case Map.fetch(@dominios, dominio) do
    {:ok, colecciones} ->
      Enum.reduce_while(colecciones, {:ok, %{}}, fn clave, {:ok, estado} ->
        case cargar_por_clave(clave) do
          {:ok, entidades} ->
            {:cont, {:ok, Map.put(estado, clave, entidades)}}

          {:error, motivo} ->
            {:halt, {:error, {clave, motivo}}}
        end
      end)

    :error ->
      {:error, {:dominio_desconocido, dominio}}
  end
end

defp cargar_por_clave(clave) do
  case Enum.find(@colecciones, fn {nombre, _, _, _} -> nombre == clave end) do
    {_, archivo, modulo, campo_id} ->
      cargar_coleccion(archivo, modulo, campo_id)

    nil ->
      {:error, {:coleccion_desconocida, clave}}
  end
end

@doc """
Guarda todas las colecciones pertenecientes a un dominio.
"""
def guardar_dominio(estado, dominio) do
  case Map.fetch(@dominios, dominio) do
    {:ok, colecciones} ->
      Enum.reduce_while(colecciones, :ok, fn clave, :ok ->
        case guardar_coleccion(estado, clave) do
          :ok ->
            {:cont, :ok}

          {:error, motivo} ->
            {:halt, {:error, {clave, motivo}}}
        end
      end)

    :error ->
      {:error, {:dominio_desconocido, dominio}}
  end
end

  @doc """
  Carga una colección desde su archivo JSON y reconstruye sus entidades.
  """
  def cargar_coleccion(archivo, modulo, campo_id) do
    with {:ok, datos} <- JSON.cargar(archivo),
         true <- is_list(datos) || {:error, "El archivo debe contener una lista"},
         {:ok, entidades} <- reconstruir(datos, modulo),
         {:ok, indexadas} <- indexar(entidades, campo_id) do
      {:ok, indexadas}
    end
  end

  @doc """
  Guarda una colección del estado global.
  """
  def guardar_coleccion(estado, clave) do
    case Enum.find(@colecciones, fn {nombre, _, _, _} -> nombre == clave end) do
      {clave, archivo, modulo, _campo_id} ->
        entidades = Map.get(estado, clave, %{})

        datos =
          entidades
          |> Map.values()
          |> Enum.map(&apply(modulo, :a_map, [&1]))

        JSON.guardar(archivo, datos)

      nil ->
        {:error, {:coleccion_desconocida, clave}}
    end
  end

  @doc """
  Guarda todas las colecciones del estado global.
  """
  def guardar_estado(estado) do
    Enum.reduce_while(@colecciones, :ok, fn {clave, _archivo, _modulo, _campo_id},
                                           :ok ->
      case guardar_coleccion(estado, clave) do
        :ok -> {:cont, :ok}
        {:error, motivo} -> {:halt, {:error, {clave, motivo}}}
      end
    end)
  end

  defp reconstruir(datos, modulo) do
    Enum.reduce_while(datos, {:ok, []}, fn mapa, {:ok, acumulado} ->
      case apply(modulo, :desde_map, [mapa]) do
        {:ok, entidad} ->
          {:cont, {:ok, [entidad | acumulado]}}

        {:error, motivo} ->
          {:halt, {:error, motivo}}
      end
    end)
    |> case do
      {:ok, entidades} -> {:ok, Enum.reverse(entidades)}
      error -> error
    end
  end

  defp indexar(entidades, campo_id) do
    Enum.reduce_while(entidades, {:ok, %{}}, fn entidad, {:ok, acumulado} ->
      id = Map.fetch!(entidad, campo_id)

      cond do
        is_nil(id) ->
          {:halt, {:error, "Se encontró una entidad sin identificador"}}

        Map.has_key?(acumulado, id) ->
          {:halt, {:error, "Identificador duplicado: #{id}"}}

        true ->
          {:cont, {:ok, Map.put(acumulado, id, entidad)}}
      end
    end)
  end
end
