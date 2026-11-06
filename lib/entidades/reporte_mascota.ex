defmodule Emergencia.ReporteMascota do
  alias Emergencia.GeneradorID

  @moduledoc """
  Registra los reportes de mascotas extraviadas o encontradas en una zona afectada,
  detallando sus características físicas, estado del reporte y usuario de contacto.
  """

  @tipos_permitidos [:perdida, :encontrada]
  @tamanos_permitidos [:pequeno, :mediano, :grande]
  @estados_permitidos [:activa, :posible_coincidencia, :resuelta]

  @enforce_keys [:id, :tipo, :especie, :color, :tamano, :estado, :id_zona, :id_usuario_contacto]
  defstruct [
    :id,
    :tipo,
    :especie,
    :nombre,
    :caracteristicas,
    :color,
    :tamano,
    :estado,
    :fecha_reporte,
    :id_zona,
    :id_usuario_contacto
  ]

  @type tipo_reporte :: :perdida | :encontrada
  @type tamano :: :pequeno | :mediano | :grande
  @type estado_reporte :: :activa | :posible_coincidencia | :resuelta
  @type t :: %__MODULE__{
          id: String.t(),
          tipo: tipo_reporte(),
          especie: String.t(),
          nombre: String.t() | nil,
          caracteristicas: String.t() | nil,
          color: String.t(),
          tamano: tamano(),
          estado: estado_reporte(),
          fecha_reporte: DateTime.t(),
          id_zona: String.t(),
          id_usuario_contacto: String.t()
        }

  @doc """
  Crea un nuevo ReporteMascota validando los tipos y campos obligatorios.
  """
  def nueva(tipo, especie, color, tamano, id_zona, id_contacto, opciones \\ []) do
    estado = Keyword.get(opciones, :estado, :activa)
    fecha = Keyword.get(opciones, :fecha_reporte, DateTime.utc_now())

    with :ok <- validar_obligatorios(especie, color, id_zona, id_contacto),
         :ok <- validar_enum(:tipo, tipo, @tipos_permitidos),
         :ok <- validar_enum(:tamano, tamano, @tamanos_permitidos),
         :ok <- validar_enum(:estado, estado, @estados_permitidos) do
      {:ok,
       %__MODULE__{
         id: GeneradorID.generar_uuid(),
         tipo: tipo,
         especie: String.downcase(String.trim(especie)),
         nombre: Keyword.get(opciones, :nombre),
         caracteristicas: Keyword.get(opciones, :caracteristicas),
         color: color,
         tamano: tamano,
         estado: estado,
         fecha_reporte: fecha,
         id_zona: id_zona,
         id_usuario_contacto: id_contacto
       }}
    end
  end

  @doc """
  Crea un nuevo ReporteMascota o lanza ArgumentError en caso de falla.
  """
  def nueva!(tipo, especie, color, tamano, id_zona, id_contacto, opciones \\ []) do
    case nueva(tipo, especie, color, tamano, id_zona, id_contacto, opciones) do
      {:ok, reporte} -> reporte
      {:error, motivo} -> raise ArgumentError, motivo
    end
  end

  # ============================================================================
  # Funciones privadas de validación
  # ============================================================================

  defp validar_obligatorios(especie, color, id_zona, id_contacto) do
    if is_nil(especie) or is_nil(color) or is_nil(id_zona) or is_nil(id_contacto) do
      {:error, "Especie, color, ID de zona e ID de usuario de contacto son obligatorios"}
    else
      :ok
    end
  end

  defp validar_enum(campo, valor, permitidos) do
    if valor in permitidos do
      :ok
    else
      {:error,
       "El campo #{campo} con valor :#{valor} es inválido. Opciones: #{inspect(permitidos)}"}
    end
  end
end
