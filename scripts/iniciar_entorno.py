
import subprocess
import time
import os
import shutil
import socket


COOKIE = "emergencia123"

# Construye el nombre del nodo servidor usando el nombre del equipo.
# Ejemplo: servidor@LAPTOP-JNLDTUOS
NODO_SERVIDOR = f"servidor@{socket.gethostname()}"


def obtener_iex():
    if os.name == "nt":
        # Ruta de instalación de Elixir en Windows.
        iex = r"C:\Program Files\Elixir\bin\iex.bat"

        if os.path.exists(iex):
            return iex

        # Como alternativa, intenta encontrarlo en PATH.
        iex = shutil.which("iex.bat") or shutil.which("iex")

    else:
        iex = shutil.which("iex")

    if iex is None:
        raise RuntimeError(
            "No se encontró IEx. Verifica la instalación de Elixir "
            "y la variable PATH."
        )

    return iex


def ejecutar(comando, directorio):
    iex = obtener_iex()

    # Sustituye el ejecutable del comando por la ruta encontrada.
    argumentos = [iex, *comando[1:]]

    # Permite que los clientes conozcan el nodo servidor.
    entorno = os.environ.copy()
    entorno["NODO_SERVIDOR"] = NODO_SERVIDOR

    if os.name == "nt":
        return subprocess.Popen(
            [
                "cmd.exe",
                "/d",
                "/k",
                "call",
                *argumentos
            ],
            cwd=directorio,
            env=entorno,
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )

    # En Linux se ejecuta en la terminal desde la que se lanzó Python.
    return subprocess.Popen(
        argumentos,
        cwd=directorio,
        env=entorno
    )


def main():
    raiz = os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))
    )

    print("\n========== SISTEMA DE EMERGENCIAS ==========")
    print(f"Nodo servidor: {NODO_SERVIDOR}")
    print("1. Iniciar servidor")
    print("2. Iniciar cliente 1")
    print("3. Iniciar cliente 2")
    print("4. Iniciar todos")
    print("5. Salir")

    opcion = input("\nSeleccione una opción: ")

    procesos = []

    if opcion in ("1", "4"):
        print("\nIniciando nodo servidor...")

        servidor = ejecutar(
            [
                "iex",
                "--sname", "servidor",
                "--cookie", COOKIE,
                "-S", "mix"
            ],
            raiz
        )

        procesos.append(servidor)

        # Da tiempo para que el servidor inicie.
        if opcion == "4":
            time.sleep(3)

    if opcion in ("2", "4"):
        print("\nIniciando cliente 1...")

        cliente1 = ejecutar(
            [
                "iex",
                "--sname", "cliente1",
                "--cookie", COOKIE,
                "-S", "mix",
                "run", "--no-start",
                "-e", "Emergencias.PruebaConexion.verificar_sistema()"
            ],
            raiz
        )

        procesos.append(cliente1)

    if opcion in ("3", "4"):
        print("\nIniciando cliente 2...")

        cliente2 = ejecutar(
            [
                "iex",
                "--sname", "cliente2",
                "--cookie", COOKIE,
                "-S", "mix",
                "run", "--no-start",
                "-e", "Emergencias.PruebaConexion.verificar_sistema()"
            ],
            raiz
        )

        procesos.append(cliente2)

    if opcion == "5":
        return

    if opcion not in ("1", "2", "3", "4"):
        print("\nOpción no válida.")
        return

    print("\nProcesos iniciados.")
    print("Cierre cada terminal cuando termine las pruebas.")

    try:
        for proceso in procesos:
            proceso.wait()

    except KeyboardInterrupt:
        print("\nFinalizando procesos...")

        for proceso in procesos:
            if proceso.poll() is None:
                proceso.terminate()


if __name__ == "__main__":
    main()
