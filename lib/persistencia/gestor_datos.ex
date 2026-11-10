defmodule Emergencia.GestorDatos do
  alias Emergencia.Almacenamiento.JSON

  alias Emergencia.{
    AsignacionRecurso,
    Usuario,
    Persona,
    Familia,
    Zona,
    CentroAcopio,
    Albergue,
    RegistroAlbergue,
    MovimientoRecurso,
    Necesidad,
    Mensaje,
    MensajeDestinatario,
    Actividad,
    ReporteMascota,
    CoincidenciaMascota,
    Recurso
  }

  @archivo_recursos "logistica.json"

  # Colecciones que se guardan y cargan.
  # Formato: {clave_estado, archivo, modulo, campo_id}
  @colecciones [
    {:usuarios, "usuarios.json", Usuario, :id},
    {:personas, "personas.json", Persona, :id},
    {:familias, "familias.json", Familia, :id},
    {:zonas, "zonas.json", Zona, :id},
    {:albergues, "albergues.json", Albergue, :id},
    {:registros_albergues, "registros_albergues.json", RegistroAlbergue, :id},
    {:centros_acopio, "centros_acopio.json", CentroAcopio, :id},
    {:necesidades, "necesidades.json", Necesidad, :id},
    {:mensajes, "mensajes.json", Mensaje, :id_envio},
    {:mensajes_destinatarios, "mensajes_destinatarios.json", MensajeDestinatario,
     :id_mensaje_destinatario},
    {:actividades, "actividades.json", Actividad, :id},
    {:reportes_mascotas, "reportes_mascotas.json", ReporteMascota, :id},
    {:coincidencias_mascotas, "coincidencias_mascotas.json", CoincidenciaMascota, :id}
  ]

  @dominios %{
    usuarios: [:usuarios],
    territorio: [:zonas, :centros_acopio],
    poblacion: [:personas, :familias, :albergues, :registros_albergues],
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

  def cargar_estado_recursos do
    case JSON.cargar(@archivo_recursos) do
      {:ok, mapa} when is_map(mapa) ->
        reconstruir_estado_recursos(mapa)

      {:ok, []} ->
        migrar_datos_recursos_anteriores()

      {:ok, otro} ->
        {:error,
         "El archivo #{@archivo_recursos} debe contener un objeto JSON, se recibió #{inspect(otro)}"}

      error ->
        error
    end
  end

  def guardar_estado_recursos(estado) when is_map(estado) do
    JSON.guardar(@archivo_recursos, %{
      "recursos" => serializar_coleccion(estado.recursos, Recurso),
      "existencias" =>
        Enum.map(estado.existencias, fn {{codigo, ubicacion}, cantidad} ->
          %{"codigo_recurso" => codigo, "ubicacion" => ubicacion, "cantidad" => cantidad}
        end),
      "movimientos" => serializar_coleccion(estado.movimientos, MovimientoRecurso),
      "necesidades" => serializar_coleccion(estado.necesidades, Necesidad),
      "asignaciones" => serializar_coleccion(estado.asignaciones, AsignacionRecurso)
    })
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

  defp reconstruir_estado_recursos(mapa) do
    with {:ok, recursos} <- reconstruir_coleccion(Map.get(mapa, "recursos", []), Recurso),
         {:ok, movimientos} <-
           reconstruir_coleccion(Map.get(mapa, "movimientos", []), MovimientoRecurso),
         {:ok, existencias} <- reconstruir_existencias(Map.get(mapa, "existencias", [])),
         {:ok, necesidades} <- cargar_o_migrar_necesidades(mapa),
         {:ok, asignaciones} <-
           reconstruir_coleccion(Map.get(mapa, "asignaciones", []), AsignacionRecurso) do
      {:ok,
       %{
         recursos: Map.new(recursos, &{&1.id, &1}),
         existencias: existencias,
         movimientos: Map.new(movimientos, &{&1.id, &1}),
         necesidades: Map.new(necesidades, &{&1.id, &1}),
         asignaciones: Map.new(asignaciones, &{&1.id, &1})
       }}
    end
  end

  defp cargar_o_migrar_necesidades(mapa) do
    case Map.fetch(mapa, "necesidades") do
      {:ok, lista} -> reconstruir_coleccion(lista, Necesidad)
      :error -> cargar_coleccion("necesidades.json", Necesidad, :id)
    end
  end

  defp migrar_datos_recursos_anteriores do
    with {:ok, recursos} <- cargar_coleccion("recursos.json", Recurso, :id),
         {:ok, necesidades} <- cargar_coleccion("necesidades.json", Necesidad, :id) do
      {:ok, %{recursos: recursos, necesidades: necesidades}}
    end
  end

  defp reconstruir_coleccion(datos, modulo) when is_list(datos), do: reconstruir(datos, modulo)
  defp reconstruir_coleccion(_, _), do: {:error, "La colección debe ser una lista"}

  defp reconstruir_existencias(lista) when is_list(lista) do
    Enum.reduce_while(lista, {:ok, %{}}, fn
      %{"codigo_recurso" => codigo, "ubicacion" => ubicacion, "cantidad" => cantidad}, {:ok, acc}
      when is_binary(codigo) and is_binary(ubicacion) and is_integer(cantidad) and cantidad >= 0 ->
        {:cont, {:ok, Map.put(acc, {codigo, ubicacion}, cantidad)}}

      _, _ ->
        {:halt, {:error, "Registro de existencias inválido"}}
    end)
  end

  defp reconstruir_existencias(_), do: {:error, "Las existencias deben ser una lista"}

  defp serializar_coleccion(coleccion, modulo) do
    Enum.map(coleccion, fn {_id, entidad} -> apply(modulo, :a_map, [entidad]) end)
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
