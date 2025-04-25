#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script orquestador para configurar un entorno de desarrollo limpio para IA/ML en Windows 11.
Este script puede ejecutar todo el proceso de limpieza e instalación desde un solo comando.
"""

import os
import sys
import platform
import subprocess
import argparse
import ctypes
import time
from pathlib import Path

# Colores para salida en consola
class Colors:
    SUCCESS = '\033[92m'  # Verde
    WARNING = '\033[93m'  # Amarillo
    ERROR = '\033[91m'    # Rojo
    INFO = '\033[94m'     # Azul
    BOLD = '\033[1m'      # Negrita
    RESET = '\033[0m'     # Resetear color

def log(message, status="INFO"):
    """Imprime mensajes formateados con colores en la consola."""
    status_color = {
        "SUCCESS": Colors.SUCCESS,
        "WARNING": Colors.WARNING,
        "ERROR": Colors.ERROR,
        "INFO": Colors.INFO,
        "TITLE": Colors.BOLD + Colors.INFO
    }.get(status, Colors.INFO)
    
    print(f"{status_color}[{status}]{Colors.RESET} {message}")

def is_admin():
    """Verifica si el script se está ejecutando con privilegios de administrador."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        return False

def run_powershell_script(script_path, args=None):
    """Ejecuta un script PowerShell y devuelve el código de salida."""
    if not os.path.exists(script_path):
        log(f"Script no encontrado: {script_path}", "ERROR")
        return False
    
    # Construir el comando
    command = ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_path]
    if args:
        command.extend(args)
    
    log(f"Ejecutando: {os.path.basename(script_path)}", "INFO")
    
    try:
        process = subprocess.run(command, check=True)
        return process.returncode == 0
    except subprocess.CalledProcessError as e:
        log(f"Error al ejecutar {os.path.basename(script_path)}: {e}", "ERROR")
        return False
    except Exception as e:
        log(f"Error inesperado: {e}", "ERROR")
        return False

def run_python_script(script_path, args=None):
    """Ejecuta un script Python y devuelve el código de salida."""
    if not os.path.exists(script_path):
        log(f"Script no encontrado: {script_path}", "ERROR")
        return False
    
    # Construir el comando
    command = [sys.executable, script_path]
    if args:
        command.extend(args)
    
    log(f"Ejecutando: {os.path.basename(script_path)}", "INFO")
    
    try:
        process = subprocess.run(command, check=True)
        return process.returncode == 0
    except subprocess.CalledProcessError as e:
        log(f"Error al ejecutar {os.path.basename(script_path)}: {e}", "ERROR")
        return False
    except Exception as e:
        log(f"Error inesperado: {e}", "ERROR")
        return False

def show_requirements():
    """Muestra los requisitos del sistema para la instalación."""
    log("REQUISITOS DEL SISTEMA", "TITLE")
    print("\nPara una instalación exitosa, asegúrate de que tu sistema cumpla con estos requisitos:")
    print("1. Windows 11 (64 bits)")
    print("2. Al menos 50 GB de espacio libre en disco")
    print("3. Al menos 8 GB de RAM (16 GB recomendado)")
    print("4. Conexión a Internet")
    print("5. Tarjeta gráfica NVIDIA compatible con CUDA")
    print("6. Privilegios de administrador")
    print("\nAdemás, para la instalación de cuDNN necesitarás:")
    print("1. Una cuenta NVIDIA Developer (gratuita)")
    print("2. Descargar manualmente el paquete cuDNN compatible con CUDA 12.4")
    print("\nIMPORTANTE: Este proceso eliminará completamente las instalaciones existentes de:")
    print("- Visual Studio")
    print("- Python")
    print("- CUDA y componentes relacionados")
    print("\nAsegúrate de hacer una copia de seguridad de tus datos importantes antes de continuar.")

def process_cleanup():
    """Ejecuta el proceso de limpieza del sistema."""
    log("INICIANDO PROCESO DE LIMPIEZA", "TITLE")
    
    # Ruta al script de limpieza
    cleanup_script = str(Path(__file__).parent / "cleanup.ps1")
    
    success = run_powershell_script(cleanup_script)
    if success:
        log("Proceso de limpieza completado exitosamente.", "SUCCESS")
        
        # Ejecutar verificador de limpieza
        verify_cleanup_success = verify_cleanup()
        if not verify_cleanup_success:
            log("El verificador de limpieza ha detectado componentes que aún están presentes.", "WARNING")
            retry = input("¿Deseas intentar ejecutar nuevamente el script de limpieza? (S/N): ")
            if retry.upper() == "S":
                log("Ejecutando nuevamente el proceso de limpieza...", "INFO")
                return process_cleanup()
            else:
                log("Se recomienda realizar una limpieza manual de los componentes detectados antes de continuar.", "WARNING")
                continue_anyway = input("¿Deseas continuar de todos modos con la instalación? (S/N): ")
                if continue_anyway.upper() != "S":
                    log("Instalación cancelada por el usuario.", "INFO")
                    return False
        
        # Preguntar por reinicio
        log("Se recomienda reiniciar el sistema antes de continuar con la instalación.", "WARNING")
        restart = input("¿Quieres reiniciar el sistema ahora? (S/N): ")
        if restart.upper() == "S":
            log("Reiniciando el sistema...", "INFO")
            subprocess.run(["shutdown", "/r", "/t", "10"])
            log("El sistema se reiniciará en 10 segundos. El script debe ejecutarse nuevamente después del reinicio.", "INFO")
            sys.exit(0)
    else:
        log("Proceso de limpieza completado con errores. Revisa el archivo de log para más detalles.", "WARNING")
    
    return success

def verify_cleanup():
    """Ejecuta la verificación de limpieza del sistema."""
    log("VERIFICANDO LIMPIEZA DEL SISTEMA", "TITLE")
    
    # Ruta al script de verificación de limpieza
    verify_cleanup_script = str(Path(__file__).parent / "verify_cleanup.ps1")
    
    success = run_powershell_script(verify_cleanup_script)
    if success:
        log("Verificación de limpieza completada exitosamente. El sistema está limpio.", "SUCCESS")
    else:
        log("Verificación de limpieza completada con advertencias. Algunos componentes aún están presentes.", "WARNING")
    
    return success

def process_installation():
    """Ejecuta el proceso de instalación del entorno."""
    log("INICIANDO PROCESO DE INSTALACIÓN", "TITLE")
    
    # Ruta al script de instalación
    install_script = str(Path(__file__).parent / "install.ps1")
    
    success = run_powershell_script(install_script)
    if success:
        log("Proceso de instalación completado exitosamente.", "SUCCESS")
        log("Para completar la configuración, es necesario instalar cuDNN manualmente.", "INFO")
        log("Consulta las instrucciones en el archivo README.md o utiliza el script setup_cudnn.ps1", "INFO")
    else:
        log("Proceso de instalación completado con errores. Revisa el archivo de log para más detalles.", "WARNING")
    
    return success

def process_verification():
    """Ejecuta el proceso de verificación del entorno."""
    log("INICIANDO PROCESO DE VERIFICACIÓN", "TITLE")
    
    # Ruta al script de verificación
    verify_script = str(Path(__file__).parent / "verify.py")
    
    success = run_python_script(verify_script)
    if success:
        log("Verificación completada exitosamente. El entorno está correctamente configurado.", "SUCCESS")
    else:
        log("Verificación completada con errores. Revisa los resultados para más detalles.", "WARNING")
    
    return success

def process_cudnn_setup():
    """Guía para la instalación de cuDNN."""
    log("CONFIGURACIÓN DE CUDNN", "TITLE")
    
    # Ruta al script de configuración de cuDNN
    cudnn_script = str(Path(__file__).parent / "setup_cudnn.ps1")
    
    log("cuDNN requiere descarga manual desde NVIDIA Developer:", "INFO")
    log("1. Visita: https://developer.nvidia.com/cudnn", "INFO")
    log("2. Inicia sesión o crea una cuenta gratuita", "INFO")
    log("3. Descarga la versión compatible con CUDA 12.4", "INFO")
    log("4. Una vez descargado, ejecuta el script setup_cudnn.ps1", "INFO")
    
    download_choice = input("¿Ya has descargado cuDNN y quieres instalarlo ahora? (S/N): ")
    if download_choice.upper() == "S":
        success = run_powershell_script(cudnn_script)
        if success:
            log("Configuración de cuDNN completada exitosamente.", "SUCCESS")
        else:
            log("Configuración de cuDNN completada con errores. Revisa el archivo de log para más detalles.", "WARNING")
        return success
    else:
        log("Puedes ejecutar el script setup_cudnn.ps1 más tarde cuando hayas descargado cuDNN.", "INFO")
        return True

def main():
    """Función principal que orquesta todo el proceso."""
    # Verificar sistema operativo
    if platform.system() != "Windows":
        log("Este script solo está diseñado para ejecutarse en Windows.", "ERROR")
        return 1
    
    # Verificar si se ejecuta como administrador
    if not is_admin():
        log("Este script requiere privilegios de administrador.", "ERROR")
        log("Por favor, ejecuta el script como administrador.", "INFO")
        return 1
    
    # Parsear argumentos de línea de comandos
    parser = argparse.ArgumentParser(description="Configuración de entorno de desarrollo para IA/ML en Windows 11")
    parser.add_argument("--clean", action="store_true", help="Ejecutar solo el proceso de limpieza")
    parser.add_argument("--verify-cleanup", action="store_true", help="Verificar que la limpieza se realizó correctamente")
    parser.add_argument("--install", action="store_true", help="Ejecutar solo el proceso de instalación")
    parser.add_argument("--verify", action="store_true", help="Ejecutar solo el proceso de verificación")
    parser.add_argument("--cudnn", action="store_true", help="Ejecutar solo la configuración de cuDNN")
    parser.add_argument("--full", action="store_true", help="Ejecutar todo el proceso (limpieza, verificación de limpieza, instalación, verificación, cuDNN)")
    parser.add_argument("--requirements", action="store_true", help="Mostrar los requisitos del sistema")
    
    args = parser.parse_args()
    
    # Si no se proporciona ningún argumento, mostrar ayuda
    if not any(vars(args).values()):
        parser.print_help()
        return 0
    
    # Mostrar requisitos
    if args.requirements:
        show_requirements()
        return 0
    
    # Mostrar banner
    print("\n" + "="*80)
    log("CONFIGURACIÓN DE ENTORNO DE DESARROLLO PARA IA/ML EN WINDOWS 11", "TITLE")
    print("="*80 + "\n")
    
    success = True
    
    # Ejecutar procesos según los argumentos
    if args.clean or args.full:
        success = process_cleanup() and success
        if args.full and not success:
            log("El proceso de limpieza falló. No se continuará con la instalación.", "ERROR")
            return 1
    
    if args.verify_cleanup or (args.full and not args.clean):
        success = verify_cleanup() and success
        if args.full and not success:
            proceed = input("La verificación de limpieza falló. ¿Deseas continuar de todos modos? (S/N): ")
            if proceed.upper() != "S":
                log("Instalación cancelada por el usuario.", "INFO")
                return 1
    
    if args.install or args.full:
        success = process_installation() and success
    
    if args.cudnn or args.full:
        success = process_cudnn_setup() and success
    
    if args.verify or args.full:
        success = process_verification() and success
    
    print("\n" + "="*80)
    if success:
        log("PROCESO COMPLETADO EXITOSAMENTE", "SUCCESS")
    else:
        log("PROCESO COMPLETADO CON ERRORES", "WARNING")
    print("="*80 + "\n")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
