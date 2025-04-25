#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script de verificación para comprobar que todos los componentes del entorno 
de desarrollo de IA/ML se han instalado correctamente en Windows 11.
"""

import os
import sys
import platform
import subprocess
import ctypes
import importlib.util
from pathlib import Path

# Colores para salida en consola
class Colors:
    SUCCESS = '\033[92m'  # Verde
    WARNING = '\033[93m'  # Amarillo
    ERROR = '\033[91m'    # Rojo
    INFO = '\033[94m'     # Azul
    RESET = '\033[0m'     # Resetear color

def log(message, status="INFO"):
    """Imprime mensajes formateados con colores en la consola."""
    status_color = {
        "SUCCESS": Colors.SUCCESS,
        "WARNING": Colors.WARNING,
        "ERROR": Colors.ERROR,
        "INFO": Colors.INFO
    }.get(status, Colors.INFO)
    
    print(f"{status_color}[{status}]{Colors.RESET} {message}")

def is_admin():
    """Verifica si el script se está ejecutando con privilegios de administrador."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except:
        return False

def run_command(command):
    """Ejecuta un comando y devuelve la salida."""
    try:
        result = subprocess.run(
            command, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE,
            shell=True,
            text=True
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), -1

def check_path_env(name, search_pattern):
    """Verifica si una ruta específica está en la variable PATH."""
    paths = os.environ.get('PATH', '').split(os.pathsep)
    found = False
    for path in paths:
        if search_pattern.lower() in path.lower():
            found = True
            log(f"✅ {name} encontrado en PATH: {path}", "SUCCESS")
            return True
    
    if not found:
        log(f"❌ {name} no encontrado en PATH", "ERROR")
    return found

def check_python():
    """Verifica la instalación de Python."""
    log("Verificando Python...", "INFO")
    
    # Comprobar si Python está instalado y su versión
    stdout, stderr, returncode = run_command("python --version")
    if returncode != 0:
        log("❌ Python no está instalado o no está en PATH", "ERROR")
        return False
    
    log(f"✅ {stdout}", "SUCCESS")
    
    # Verificar la versión de Python (queremos 3.10.x)
    version = stdout.split()[1]
    if not version.startswith("3.10."):
        log(f"⚠️ La versión de Python es {version}, se recomienda 3.10.x", "WARNING")
    
    # Verificar pip
    stdout, stderr, returncode = run_command("pip --version")
    if returncode != 0:
        log("❌ pip no está instalado o no está en PATH", "ERROR")
        return False
    
    log(f"✅ {stdout}", "SUCCESS")
    
    # Verificar path en variables de entorno
    check_path_env("Python", "python")
    
    return True

def check_visual_studio():
    """Verifica la instalación de Visual Studio."""
    log("Verificando Visual Studio...", "INFO")
    
    # Comprobar instalación de Visual Studio Community 2022
    vs_paths = [
        r"C:\Program Files\Microsoft Visual Studio\2022\Community",
        r"C:\Program Files (x86)\Microsoft Visual Studio\2022\Community"
    ]
    
    vs_found = False
    for path in vs_paths:
        if os.path.exists(path):
            vs_found = True
            log(f"✅ Visual Studio 2022 encontrado en: {path}", "SUCCESS")
            break
    
    if not vs_found:
        log("❌ Visual Studio 2022 Community no encontrado", "ERROR")
    
    # Verificar cl.exe (compilador C/C++)
    cl_paths = [
        r"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
        r"C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe"
    ]
    
    cl_found = False
    for cl_path_pattern in cl_paths:
        possible_paths = list(Path().glob(cl_path_pattern))
        if possible_paths:
            cl_found = True
            log(f"✅ Compilador C/C++ (cl.exe) encontrado en: {possible_paths[0]}", "SUCCESS")
            break
    
    if not cl_found:
        log("❌ Compilador C/C++ (cl.exe) no encontrado", "ERROR")
    
    # Verificar los workloads instalados usando vswhere
    vswhere_path = r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if os.path.exists(vswhere_path):
        stdout, stderr, returncode = run_command(f'"{vswhere_path}" -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -property displayName')
        if stdout:
            log(f"✅ Carga de trabajo 'Desktop development with C++' instalada", "SUCCESS")
        else:
            log("❌ Carga de trabajo 'Desktop development with C++' no encontrada", "ERROR")
        
        stdout, stderr, returncode = run_command(f'"{vswhere_path}" -products * -requires Microsoft.VisualStudio.Workload.Python -property displayName')
        if stdout:
            log(f"✅ Carga de trabajo 'Python development' instalada", "SUCCESS")
        else:
            log("❌ Carga de trabajo 'Python development' no encontrada", "ERROR")
    else:
        log("⚠️ vswhere.exe no encontrado, no se pueden verificar cargas de trabajo de VS", "WARNING")
    
    return vs_found and cl_found

def check_cuda():
    """Verifica la instalación de CUDA."""
    log("Verificando CUDA...", "INFO")
    
    # Verificar NVCC (compilador CUDA)
    stdout, stderr, returncode = run_command("nvcc --version")
    if returncode != 0:
        log("❌ CUDA (nvcc) no está instalado o no está en PATH", "ERROR")
        return False
    
    log(f"✅ {stdout.splitlines()[3] if len(stdout.splitlines()) > 3 else stdout}", "SUCCESS")
    
    # Extraer versión de CUDA
    version_line = stdout.splitlines()[3] if len(stdout.splitlines()) > 3 else stdout
    if "release" in version_line.lower():
        cuda_version = version_line.split("release")[1].strip().split(",")[0]
        if not cuda_version.startswith("12.4"):
            log(f"⚠️ La versión de CUDA es {cuda_version}, se recomienda 12.4", "WARNING")
    
    # Verificar variables de entorno CUDA
    cuda_home = os.environ.get('CUDA_PATH')
    if cuda_home:
        log(f"✅ Variable de entorno CUDA_PATH configurada: {cuda_home}", "SUCCESS")
    else:
        log("❌ Variable de entorno CUDA_PATH no configurada", "ERROR")
    
    # Verificar path en variables de entorno
    check_path_env("CUDA", "cuda")
    
    # Verificar instalación de CUDNN
    cudnn_paths = [
        os.path.join(cuda_home, "include", "cudnn.h") if cuda_home else None,
        r"C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\include\cudnn.h",
        r"C:\Program Files\NVIDIA\CUDNN\v8.x\include\cudnn.h"
    ]
    
    cudnn_found = False
    for path in cudnn_paths:
        if path and os.path.exists(path):
            cudnn_found = True
            log(f"✅ cuDNN encontrado en: {path}", "SUCCESS")
            break
    
    if not cudnn_found:
        log("⚠️ cuDNN no encontrado. Recuerda instalarlo manualmente.", "WARNING")
    
    return True

def check_pytorch():
    """Verifica la instalación de PyTorch con soporte CUDA."""
    log("Verificando PyTorch y soporte CUDA...", "INFO")
    
    # Verificar si PyTorch está instalado
    spec = importlib.util.find_spec("torch")
    if spec is None:
        log("❌ PyTorch no está instalado", "ERROR")
        return False
    
    import torch
    
    log(f"✅ PyTorch {torch.__version__} instalado", "SUCCESS")
    
    # Verificar soporte CUDA
    cuda_available = torch.cuda.is_available()
    if cuda_available:
        device_count = torch.cuda.device_count()
        device_name = torch.cuda.get_device_name(0) if device_count > 0 else "Unknown"
        cuda_version = torch.version.cuda
        
        log(f"✅ CUDA está disponible para PyTorch", "SUCCESS")
        log(f"   - Dispositivos CUDA: {device_count}", "INFO")
        log(f"   - Nombre del dispositivo: {device_name}", "INFO")
        log(f"   - Versión de CUDA: {cuda_version}", "INFO")
    else:
        log("❌ CUDA no está disponible para PyTorch. Comprueba tu instalación de CUDA y PyTorch.", "ERROR")
    
    return cuda_available

def check_ml_libraries():
    """Verifica la instalación de bibliotecas comunes para ML/NLP/LLM."""
    log("Verificando bibliotecas para ML/NLP/LLM...", "INFO")
    
    libraries = {
        "numpy": "NumPy",
        "scipy": "SciPy",
        "matplotlib": "Matplotlib",
        "pandas": "Pandas",
        "sklearn": "Scikit-learn",
        "transformers": "Transformers (Hugging Face)",
        "datasets": "Datasets (Hugging Face)",
        "jupyter": "Jupyter"
    }
    
    all_installed = True
    
    for module_name, display_name in libraries.items():
        spec = importlib.util.find_spec(module_name)
        if spec is None:
            log(f"❌ {display_name} no está instalado", "ERROR")
            all_installed = False
        else:
            try:
                module = importlib.import_module(module_name)
                version = getattr(module, "__version__", "versión desconocida")
                log(f"✅ {display_name} {version} instalado", "SUCCESS")
            except ImportError:
                log(f"❌ Error al importar {display_name}", "ERROR")
                all_installed = False
    
    return all_installed

def print_system_info():
    """Imprime información del sistema."""
    log("Información del sistema:", "INFO")
    log(f"   - Sistema operativo: {platform.system()} {platform.release()} {platform.version()}", "INFO")
    log(f"   - Arquitectura: {platform.machine()}", "INFO")
    log(f"   - Procesador: {platform.processor()}", "INFO")
    
    # Información de la GPU NVIDIA
    stdout, stderr, returncode = run_command("nvidia-smi")
    if returncode == 0:
        gpu_info = stdout.split('\n')
        for i, line in enumerate(gpu_info):
            if "NVIDIA" in line and "GPU" in line:
                log(f"   - GPU: {line.strip()}", "INFO")
            elif "Driver Version" in line:
                log(f"   - Driver NVIDIA: {line.strip()}", "INFO")
            elif "CUDA Version" in line:
                log(f"   - CUDA Version (driver): {line.strip()}", "INFO")
    else:
        log("   - No se pudo obtener información de la GPU con nvidia-smi", "INFO")

def run_all_checks():
    """Ejecuta todas las verificaciones y muestra un resumen."""
    log("Iniciando verificación del entorno de desarrollo para IA/ML...", "INFO")
    print("\n" + "="*80 + "\n")
    
    print_system_info()
    print("\n" + "-"*80 + "\n")
    
    checks = [
        ("Python 3.10", check_python),
        ("Visual Studio 2022", check_visual_studio),
        ("CUDA 12.4", check_cuda),
        ("PyTorch con CUDA", check_pytorch),
        ("Bibliotecas ML/NLP", check_ml_libraries)
    ]
    
    results = {}
    for name, check_func in checks:
        print("\n" + "-"*80 + "\n")
        results[name] = check_func()
    
    print("\n" + "="*80 + "\n")
    log("Resumen de la verificación:", "INFO")
    
    all_pass = True
    for name, result in results.items():
        status = "SUCCESS" if result else "ERROR"
        log(f"{name}: {'PASS' if result else 'FAIL'}", status)
        if not result:
            all_pass = False
    
    print("\n" + "="*80 + "\n")
    
    if all_pass:
        log("¡Todo el entorno está correctamente configurado!", "SUCCESS")
    else:
        log("Se encontraron problemas en el entorno. Revisa los detalles anteriores.", "WARNING")
        log("Para solucionar problemas comunes, consulta el archivo troubleshooting.md", "INFO")
    
    return all_pass

if __name__ == "__main__":
    # Verificar si se está ejecutando en Windows
    if platform.system() != "Windows":
        log("Este script solo está diseñado para ejecutarse en Windows.", "ERROR")
        sys.exit(1)
    
    # Verificar Admin (no es obligatorio pero recomendado)
    if not is_admin():
        log("Se recomienda ejecutar este script como administrador para verificaciones completas.", "WARNING")
    
    success = run_all_checks()
    sys.exit(0 if success else 1)
