# Proyecto Final - Programación III - Sistema Distribuido de Coordinación y Gestión de Emergencias

Este repositorio contiene la solución al proyecto final de Programación III (Universidad del Quindío, Ingeniería de Sistemas y Computación). El sistema simula una plataforma distribuida para coordinar la atención posterior a un terremoto, y está desarrollado en Elixir haciendo énfasis en programación funcional, recursividad, concurrencia con GenServer, supervisión (OTP) y persistencia en archivos de texto plano (JSON).

**Integrantes**

| # | Nombre completo |
|---|-----------------|
| 1 | Juan Miguel Henao Gaviria |
| 2 | Valeria Zapata Giraldo |

## Descripción del proyecto

Después de un terremoto, distintos sectores de una ciudad quedan con afectaciones en infraestructura, comunicación y acceso a recursos. Los organismos de atención, voluntarios, albergues y ciudadanos necesitan registrar información y coordinar acciones al mismo tiempo. Este sistema es multiusuario y permite gestionar:

- **Usuarios**: registro, inicio y cierre de sesión, y restricción de operaciones según el rol (ciudadano, voluntario, coordinador y administrador). Toda operación importante queda registrada como actividad del usuario.
- **Zonas afectadas**: zonas, sectores y puntos de atención con nivel de afectación (crítico, alto, medio o bajo), centros de acopio y estadísticas acumuladas por zona.
- **Necesidades puntuales**: solicitudes de ayuda con tipo, cantidad, prioridad, destinatario y estado. La prioridad se usa para ordenar y atender las solicitudes.
- **Recursos e inventarios**: registro de recursos por ubicación, asignación a necesidades, transferencias entre ubicaciones, historial de movimientos y consulta de existencias críticas.
- **Personas y familias**: registro de personas afectadas con historial de estados, búsqueda por distintos criterios y agrupación en familias.
- **Albergues**: control de capacidad y ocupación, ingreso y salida de personas, cupos disponibles y reporte de ocupación.
- **Mensajes entre familiares**: mensajes dirigidos a una persona o familia, con estado pendiente o entregado.
- **Mascotas perdidas y encontradas**: reportes, búsqueda de posibles coincidencias por puntaje de similitud y cierre de reportes resueltos.

### Decisiones de diseño principales

- **Arquitectura por capas.** Cada capa solo conoce a la inferior:

  ```
  Entidades <- Servicios (puros) <- Servidores (GenServer) <- Aplicación (Gestión*) <- Consola (CLI)
  ```

  - `entidades`: estructuras de datos (`struct`) con sus validaciones y conversión desde/hacia JSON.
  - `servicios`: lógica de negocio pura. Reciben un estado y devuelven `{:ok, resultado, nuevo_estado}` o `{:error, motivo}`, sin lanzar excepciones en situaciones esperadas.
  - `servidores`: un `GenServer` por dominio que mantiene el estado, procesa un mensaje a la vez y persiste los cambios.
  - `aplicacion`: autorización por rol, resolución de códigos (`ZON-0001`, `NEC-0001`, documentos o UUID) y auditoría de actividades.
  - `consola`: lectura de comandos, conversión de entrada y presentación de resultados.
- **Concurrencia sin inconsistencias.** Como cada `GenServer` atiende un mensaje a la vez, si dos solicitudes compiten por las últimas unidades de un recurso solo se confirma la que cabe en el inventario real (por ejemplo, 30 + 25 litros sobre 50 disponibles). Del mismo modo, un reporte de mascota o una necesidad no se pueden cerrar dos veces.
- **Supervisión.** `Emergencia.Supervisor` supervisa con estrategia `:one_for_one` los 7 servidores de dominio (usuarios, mensajes, actividades, población, territorio, recursos y mascotas) y un `Task.Supervisor` para el procesamiento en segundo plano. Si un proceso cae, solo se reinicia ese proceso y recupera su estado desde disco.
- **Sistema distribuido.** El servidor y varios clientes se ejecutan como nodos de Erlang distintos conectados con una cookie compartida. Los clientes llaman a los servidores del nodo servidor mediante `Emergencia.NodoServidor`. El servidor registra qué nodo y qué proceso tiene cada sesión y detecta cuando un cliente se desconecta.
- **Recursividad.** Se usan funciones recursivas propias, por ejemplo: `recorrer_sectores_recursivo` y `contar_puntos_recursivo` (recorren zona → sectores → puntos de atención), `contar_estado_recursivo` (personas por estado) y `sumar_capacidad_recursivo` (capacidad total de albergues), además del bucle principal del CLI.
- **Persistencia.** Cada dominio guarda sus colecciones en archivos JSON dentro de `data/`. La escritura es atómica: primero se escribe un archivo temporal y luego se renombra.
- **Coincidencias de mascotas.** Se calcula un puntaje de similitud que combina especie, color, tamaño y zona, y solo se sugieren las parejas que superan un umbral mínimo.

## Organización de carpetas

El proyecto está diseñado bajo una arquitectura modular que separa las entidades, la lógica de negocio, los procesos, la interfaz y los datos persistidos.

```
/ProyectoFinal-p03
│
├── /data                         # Archivos JSON de persistencia (usuarios, personas, zonas, etc.)
├── /scripts
│   └── iniciar_entorno.py        # Script para abrir el servidor y los clientes automáticamente
├── /lib
│   ├── /entidades                # Estructuras del dominio (Persona, Zona, Necesidad, Recurso, ...)
│   ├── /servicios                # Lógica de negocio pura (un servicio por dominio)
│   ├── /servidores               # GenServers, nodo servidor y conexión entre nodos
│   ├── /supervisores             # Supervisor raíz (Emergencia.Supervisor)
│   ├── /aplicacion               # Gestión*: autorización, resolución de códigos y auditoría
│   ├── /persistencia             # Lectura y escritura de los archivos JSON
│   ├── /consola                  # CLI por comandos y menús de consola
│   └── /utils                    # Generador de IDs y utilidades de entrada/salida
├── /test                         # Pruebas con ExUnit
├── /.github/workflows            # Integración continua (compilación y pruebas)
├── mix.exs                       # Definición del proyecto y dependencias
└── README.md
```

## Requisitos previos

Para clonar, compilar y ejecutar este proyecto en tu máquina local, asegúrate de contar con:

- **Elixir 1.20 o superior** (el proyecto lo exige en `mix.exs`).
- **Erlang/OTP 29** (la versión usada en la integración continua; se instala junto con Elixir).
- **Git** para clonar y administrar el repositorio.
- **Python 3** (opcional, solo si quieres usar el script que abre los nodos automáticamente).
- Conexión a internet la primera vez, para descargar la dependencia `jason` con `mix deps.get`.

## Guía paso a paso: clonar y ejecutar

### Paso 1: Clonar el repositorio de GitHub

Abre la terminal de tu sistema operativo (PowerShell, Command Prompt, Terminal de macOS/Linux o Git Bash) o la terminal integrada de Visual Studio Code y ejecuta:

```
git clone https://github.com/JuanMiguel02/ProyectoFinal-p03.git
cd ProyectoFinal-p03
```

### Paso 2: Descargar dependencias y compilar

```
mix deps.get
mix compile
```

(En Windows, si `mix` no se reconoce, usa `mix.bat`.)

### Paso 3: Ejecutar el sistema

Puedes ejecutar el sistema de tres formas: con el script de Python (recomendado), manualmente con varios nodos, o en un solo nodo.

#### Opción A: Ejecución mediante el script de Python (recomendado)

El repositorio incluye el script `scripts/iniciar_entorno.py`. Este script busca el intérprete `iex` en el sistema, construye el nombre del nodo servidor a partir del nombre de tu equipo (`servidor@NOMBRE_DEL_PC`), usa la cookie `emergencia123` y abre cada nodo en su propia terminal.

Desde la raíz del proyecto:

```
python scripts/iniciar_entorno.py
```

Nota: en Linux o macOS el comando puede ser `python3 scripts/iniciar_entorno.py`.

El script muestra este menú:

```
1. Iniciar servidor
2. Iniciar cliente 1
3. Iniciar cliente 2
4. Iniciar todos
5. Salir
```

- La opción **1** abre el nodo servidor (`iex --sname servidor --cookie emergencia123 -S mix`), que levanta todos los servidores y el supervisor.
- Las opciones **2** y **3** abren un cliente (`cliente1` o `cliente2`) que se conecta automáticamente al servidor, con varios reintentos si el servidor todavía está arrancando.
- La opción **4** inicia el servidor y los dos clientes.

Cuando un cliente muestre `Conexión establecida correctamente.`, escribe en esa terminal:

```elixir
Emergencia.Consola.CLI.iniciar()
```

Así se abre la consola de comandos en ese cliente. Puedes hacerlo en los dos clientes a la vez para probar el trabajo simultáneo de dos usuarios.

#### Opción B: Ejecución manual de los nodos

Si prefieres no usar Python, abre una terminal por nodo, siempre dentro de la carpeta del proyecto. Reemplaza `NOMBRE_DEL_PC` por el nombre de tu equipo (puedes verlo con el comando `hostname`).

**1. Nodo servidor** (primera terminal):

```
iex --sname servidor --cookie emergencia123 -S mix
```

Para comprobar el nombre completo del nodo:

```elixir
Node.self()
# :"servidor@NOMBRE_DEL_PC"
```

**2. Nodo cliente** (segunda terminal; `--no-start` evita levantar los servidores en el cliente):

```
iex --sname cliente --cookie emergencia123 -S mix run --no-start
```

Conecta el cliente con el servidor y configúralo para que sus llamadas se dirijan a ese nodo:

```elixir
Node.connect(:"servidor@NOMBRE_DEL_PC")
# true

Emergencia.NodoServidor.configurar(:"servidor@NOMBRE_DEL_PC")
```

Abre la consola de comandos:

```elixir
Emergencia.Consola.CLI.iniciar()
```

**3. Segundo cliente** (tercera terminal), con otro nombre pero la misma cookie:

```
iex --sname cliente2 --cookie emergencia123 -S mix run --no-start
```

Repite `Node.connect/1`, `Emergencia.NodoServidor.configurar/1` y `Emergencia.Consola.CLI.iniciar()`.

**Ver las sesiones activas** (en la terminal del servidor): muestra qué usuarios están conectados, desde qué nodo y con qué proceso.

```elixir
:sys.get_state(Emergencia.UsuariosServidor).sesiones
```

Resultado de ejemplo:

```elixir
%{
  "b3701dbb-6da7-47d8-8ca4-fbd89ccb8fe9" => %{
    monitor: #Reference<0.1708441731.1064566789.51466>,
    pid: #PID<25786.176.0>,
    nodo: :"cliente@NOMBRE_DEL_PC"
  },
  "e204c9a4-e186-47a7-b80a-1cb1fe57b276" => %{
    monitor: #Reference<0.1708441731.1064566789.52149>,
    pid: #PID<25833.176.0>,
    nodo: :"cliente2@NOMBRE_DEL_PC"
  }
}
```

#### Opción C: Ejecución en un solo nodo

Para probar rápidamente sin distribución, no hace falta conectar nodos:

```
iex -S mix
```

```elixir
Emergencia.Consola.CLI.iniciar()
```

(Por defecto las llamadas se dirigen al propio nodo.)

## Comandos de la consola

Dentro de la consola escribe `help` para ver la lista completa y `exit` para salir. Los textos con espacios van entre comillas.

| Área | Comandos |
|------|----------|
| Autenticación | `connect <usuario> <contraseña> <tipo> <zona>`, `disconnect` |
| Territorio | `register_zone`, `register_sector`, `register_center`, `register_point`, `list_zones`, `zone_stats` |
| Necesidades y recursos | `register_need`, `register_resource`, `assign_resource`, `transfer_resource`, `list_needs`, `pending_needs`, `list_ordered_needs`, `list_resources`, `list_all_resources`, `check_stock`, `critical_resources` |
| Personas y familias | `report_person`, `find_person`, `change_person_status`, `register_family`, `add_person_to_family` |
| Albergues | `register_shelter`, `check_shelter`, `shelter_report`, `register_entry`, `register_exit` |
| Mensajes | `send_person_message`, `send_family_message`, `list_family_messages`, `confirm_delivery`, `complete_message` |
| Mascotas | `report_pet`, `match_pets`, `complete_pet` |
| General | `summary`, `help`, `exit` |

Si el usuario no existe, `connect` lo registra automáticamente; si ya existe, valida la contraseña.

### Ejemplo de flujo

```
connect laura 1234 coordinador centro
register_zone "Zona Centro" critico 5000
register_center "Centro de Acopio Norte" "Calle 10 # 5-20" 500 ZON-0001
register_need agua 30 critica ZON-0001 ZON-0001 "Punto de atención sector 3"
register_resource Agua 50 litros CAC-0001
assign_resource NEC-0001 Agua 30
report_person 1001 "Andres Gomez" ZON-0001 localizada
send_person_message 1001 "Estoy bien, estoy en el albergue norte"
report_pet lost perro "Luna" negra mediano ZON-0001 "Andres Gomez"
report_pet found perro desconocido negra mediano ZON-0001 "Centro de rescate"
match_pets
change_person_status PER-0001 reunificada
summary
```

Los códigos (`ZON-0001`, `CAC-0001`, `NEC-0001`, `PER-0001`, etc.) los genera el sistema; usa los que te devuelve cada comando. La ubicación de `register_resource` debe ser un centro de acopio, un punto de atención o un albergue ya registrado.

## Pruebas

Las pruebas se ejecutan con ExUnit desde la raíz del proyecto:

```
mix test
```

Las pruebas incluyen casos de servicios (territorio, recursos y mascotas), autenticación de usuarios y una prueba de **concurrencia** en la que dos procesos compiten por el mismo inventario limitado: una asignación se confirma, la otra se rechaza por inventario insuficiente y el inventario final nunca queda negativo.
