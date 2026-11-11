defmodule Emergencia.Aplicacion.GestionMascotas do
  @moduledoc """
  Coordina el registro de reportes de mascotas, búsqueda de coincidencias y resolución.
  """

  alias Emergencia.Cliente.Sesion
  alias Emergencia.Aplicacion.Autenticacion
  alias Emergencia.MascotasServidor
  alias Emergencia.ActividadesServidor
  alias Emergencia.TerritorioServidor

  @estados_reporte %{
    "activa" => :activa,
    "posible_coincidencia" => :posible_coincidencia,
    "resuelta" => :resuelta
  }

  def registrar_reporte(sesion, tipo, especie, color, tamano, zona_cod, contacto, opciones \\ [])

  def registrar_reporte(
        %Sesion{} = sesion,
        tipo,
        especie,
        color,
        tamano,
        zona_cod,
        _contacto,
        opciones
      ) do
    with :ok <- Autenticacion.autorizar(sesion, :crear_reporte_mascota),
         {:ok, zona} <- TerritorioServidor.buscar_zona(zona_cod),
         {:ok, reporte} <-
           MascotasServidor.registrar_reporte(
             tipo,
             especie,
             color,
             tamano,
             zona.id,
             sesion.id_usuario,
             opciones
           ) do
      registrar_con_advertencia(
        reporte,
        sesion.id_usuario,
        :registrar_reporte_mascota,
        "El usuario #{sesion.nombre_usuario} registró reporte de mascota #{tipo}"
      )
    end
  end

  def registrar_reporte(_, _, _, _, _, _, _, _), do: {:error, :sesion_invalida}

  def listar_reportes(sesion, criterios \\ [])

  def listar_reportes(%Sesion{} = sesion, criterios) when is_list(criterios) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes),
         {:ok, criterios_resueltos} <- resolver_filtros(criterios) do
      MascotasServidor.buscar_reportes(criterios_resueltos)
    end
  end

  def listar_reportes(_, _), do: {:error, :sesion_invalida}

  def listar_coincidencias(%Sesion{} = sesion) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes) do
      MascotasServidor.listar_coincidencias()
    end
  end

  def listar_coincidencias(_), do: {:error, :sesion_invalida}

  def registrar_coincidencia_reportes(
        %Sesion{} = sesion,
        id_o_codigo_perdida,
        id_o_codigo_encontrada
      ) do
    with :ok <- Autenticacion.autorizar(sesion, :confirmar_coincidencia),
         {:ok, reportes} <- MascotasServidor.listar_reportes(),
         {:ok, perdida} <- buscar_reporte(reportes, id_o_codigo_perdida),
         {:ok, encontrada} <- buscar_reporte(reportes, id_o_codigo_encontrada),
         {:ok, coincidencia} <-
           MascotasServidor.registrar_coincidencia(
             perdida.id,
             encontrada.id,
             sesion.id_usuario
           ) do
      registrar_con_advertencia(
        coincidencia,
        sesion.id_usuario,
        :registrar_coincidencia_mascota,
        "El usuario #{sesion.nombre_usuario} registró una posible coincidencia de mascota"
      )
    end
  end

  def registrar_coincidencia_reportes(_, _, _), do: {:error, :sesion_invalida}

  def confirmar_coincidencia(%Sesion{} = sesion, id_coincidencia) do
    with :ok <- Autenticacion.autorizar(sesion, :confirmar_coincidencia),
         {:ok, coincidencia} <-
           MascotasServidor.confirmar_coincidencia(id_coincidencia, sesion.id_usuario) do
      registrar_con_advertencia(
        coincidencia,
        sesion.id_usuario,
        :confirmar_coincidencia_mascota,
        "El usuario #{sesion.nombre_usuario} confirmó una coincidencia de mascota"
      )
    end
  end

  def confirmar_coincidencia(_, _), do: {:error, :sesion_invalida}

  def confirmar_coincidencia_reportes(
        %Sesion{} = sesion,
        id_o_codigo_perdida,
        id_o_codigo_encontrada
      ) do
    with :ok <- Autenticacion.autorizar(sesion, :confirmar_coincidencia),
         {:ok, reportes} <- MascotasServidor.listar_reportes(),
         {:ok, perdida} <- buscar_reporte(reportes, id_o_codigo_perdida),
         {:ok, encontrada} <- buscar_reporte(reportes, id_o_codigo_encontrada),
         {:ok, coincidencia} <-
           MascotasServidor.registrar_y_confirmar_coincidencia(
             perdida.id,
             encontrada.id,
             sesion.id_usuario
           ) do
      registrar_con_advertencia(
        coincidencia,
        sesion.id_usuario,
        :confirmar_coincidencia_mascota,
        "El usuario #{sesion.nombre_usuario} confirmó una coincidencia de mascota"
      )
    end
  end

  def confirmar_coincidencia_reportes(_, _, _), do: {:error, :sesion_invalida}

  def buscar_coincidencias(%Sesion{} = sesion, id_reporte) do
    with :ok <- Autenticacion.autorizar(sesion, :consultar_reportes) do
      MascotasServidor.buscar_coincidencias(id_reporte)
    end
  end

  def buscar_coincidencias(_, _), do: {:error, :sesion_invalida}

  def resolver_reporte(%Sesion{} = sesion, id_reporte) do
    with :ok <- Autenticacion.autorizar(sesion, :gestionar_coincidencias),
         {:ok, reporte} <- MascotasServidor.resolver_reporte(id_reporte, sesion.id_usuario) do
      registrar_con_advertencia(
        reporte,
        sesion.id_usuario,
        :resolver_reporte,
        "El usuario #{sesion.nombre_usuario} marcó como resuelto el reporte " <>
          "#{Map.get(reporte, :codigo_reporte) || reporte.id}"
      )
    end
  end

  def resolver_reporte(_, _), do: {:error, :sesion_invalida}

  defp resolver_filtros(criterios) do
    Enum.reduce_while(criterios, {:ok, []}, fn
      {:especie, especie}, {:ok, acumulados} when is_binary(especie) ->
        {:cont, {:ok, [{:especie, String.downcase(String.trim(especie))} | acumulados]}}

      {:id_zona, zona}, {:ok, acumulados} when is_binary(zona) ->
        case TerritorioServidor.buscar_zona(zona) do
          {:ok, zona_encontrada} ->
            {:cont, {:ok, [{:id_zona, zona_encontrada.id} | acumulados]}}

          {:error, motivo} ->
            {:halt, {:error, motivo}}
        end

      {:estado, estado}, {:ok, acumulados} ->
        case estado_reporte(estado) do
          {:ok, estado_normalizado} ->
            {:cont, {:ok, [{:estado, estado_normalizado} | acumulados]}}

          {:error, motivo} ->
            {:halt, {:error, motivo}}
        end

      {campo, _valor}, _acc ->
        {:halt, {:error, "Filtro no válido para reportes de mascotas: #{inspect(campo)}"}}
    end)
  end

  defp estado_reporte(estado) when is_atom(estado) do
    estado_reporte(Atom.to_string(estado))
  end

  defp estado_reporte(estado) when is_binary(estado) do
    case Map.fetch(@estados_reporte, String.downcase(String.trim(estado))) do
      {:ok, valor} ->
        {:ok, valor}

      :error ->
        {:error, "Estado no válido: '#{estado}'. Usa activa, posible_coincidencia o resuelta."}
    end
  end

  defp estado_reporte(_), do: {:error, "El estado del reporte debe ser texto válido."}

  defp buscar_reporte(reportes, identificador) do
    codigo = String.upcase(identificador)

    case Enum.filter(reportes, fn reporte ->
           reporte.id == identificador or
             (Map.get(reporte, :codigo_reporte) != nil and
                String.upcase(reporte.codigo_reporte) == codigo)
         end) do
      [reporte] -> {:ok, reporte}
      [] -> {:error, "No se encontró un reporte de mascota con '#{identificador}'."}
      _ -> {:error, "Hay varios reportes coincidentes; utilice un identificador más específico."}
    end
  end

  defp registrar_con_advertencia(resultado, id_responsable, accion, descripcion) do
    case ActividadesServidor.registrar(id_responsable, accion, descripcion) do
      {:ok, _act} -> {:ok, resultado}
      {:error, motivo} -> {:ok, resultado, {:advertencia, {:error_auditoria, motivo}}}
    end
  end
end
