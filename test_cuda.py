#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Script para probar la funcionalidad básica de CUDA.
Realiza pruebas más allá de PyTorch para verificar que CUDA
está correctamente instalado y funcionando.
"""

import os
import sys
import time
import subprocess
import platform
import argparse
import ctypes
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

def check_cuda_driver():
    """Verifica la instalación del controlador NVIDIA."""
    log("Verificando controlador NVIDIA...", "INFO")
    
    stdout, stderr, returncode = run_command("nvidia-smi")
    if returncode != 0:
        log("❌ No se pudo ejecutar nvidia-smi. El controlador NVIDIA puede no estar instalado correctamente.", "ERROR")
        log(f"Error: {stderr}", "ERROR")
        return False
    
    # Extraer información relevante
    driver_version = None
    cuda_version = None
    gpu_name = None
    
    for line in stdout.split('\n'):
        if "Driver Version" in line:
            driver_version = line.split(':')[1].strip()
        if "CUDA Version" in line:
            cuda_version = line.split(':')[1].strip()
        if "NVIDIA" in line and ("RTX" in line or "GTX" in line or "Quadro" in line or "Tesla" in line):
            gpu_name = line.strip()
    
    if driver_version:
        log(f"✅ Controlador NVIDIA: {driver_version}", "SUCCESS")
    if cuda_version:
        log(f"✅ Versión CUDA (controlador): {cuda_version}", "SUCCESS")
    if gpu_name:
        log(f"✅ GPU detectada: {gpu_name}", "SUCCESS")
    
    log(f"Salida completa de nvidia-smi:\n{stdout}", "INFO")
    return True

def check_nvcc():
    """Verifica la instalación del compilador CUDA (nvcc)."""
    log("Verificando compilador CUDA (nvcc)...", "INFO")
    
    stdout, stderr, returncode = run_command("nvcc --version")
    if returncode != 0:
        log("❌ No se pudo ejecutar nvcc. El toolkit CUDA puede no estar instalado correctamente.", "ERROR")
        log(f"Error: {stderr}", "ERROR")
        return False
    
    log(f"✅ {stdout}", "SUCCESS")
    return True

def test_pytorch_cuda():
    """Prueba la funcionalidad de CUDA con PyTorch."""
    log("Verificando PyTorch con CUDA...", "INFO")
    
    try:
        import torch
        log(f"✅ PyTorch versión {torch.__version__} encontrado", "SUCCESS")
        
        if torch.cuda.is_available():
            log(f"✅ CUDA disponible para PyTorch", "SUCCESS")
            log(f"   - Dispositivos CUDA: {torch.cuda.device_count()}", "INFO")
            for i in range(torch.cuda.device_count()):
                log(f"   - Dispositivo {i}: {torch.cuda.get_device_name(i)}", "INFO")
            log(f"   - Versión CUDA: {torch.version.cuda}", "INFO")
            
            # Prueba simple
            x = torch.rand(1000, 1000).cuda()
            y = torch.rand(1000, 1000).cuda()
            
            # Calentamiento
            z = torch.matmul(x, y)
            
            # Medir tiempo de operación con CUDA
            start = time.time()
            for _ in range(10):
                z = torch.matmul(x, y)
            torch.cuda.synchronize()  # Esperar a que terminen todas las operaciones CUDA
            cuda_time = time.time() - start
            
            # Medir tiempo con CPU
            x_cpu = x.cpu()
            y_cpu = y.cpu()
            start = time.time()
            for _ in range(10):
                z_cpu = torch.matmul(x_cpu, y_cpu)
            cpu_time = time.time() - start
            
            speedup = cpu_time / cuda_time
            
            log(f"✅ Prueba de rendimiento:", "SUCCESS")
            log(f"   - Tiempo con GPU: {cuda_time:.4f} segundos", "INFO")
            log(f"   - Tiempo con CPU: {cpu_time:.4f} segundos", "INFO")
            log(f"   - Aceleración: {speedup:.2f}x", "INFO")
            
            if speedup > 1:
                log(f"✅ La GPU es {speedup:.2f}x más rápida que la CPU!", "SUCCESS")
            else:
                log(f"⚠️ La CPU fue más rápida que la GPU para esta operación. Esto puede ocurrir con operaciones pequeñas debido a la sobrecarga de transferencia.", "WARNING")
            
            return True
        else:
            log("❌ CUDA no está disponible para PyTorch", "ERROR")
            log("   Verifica que CUDA y cuDNN estén correctamente instalados", "ERROR")
            return False
    except ImportError:
        log("❌ No se pudo importar PyTorch. Asegúrate de que esté instalado con pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124", "ERROR")
        return False
    except Exception as e:
        log(f"❌ Error al probar PyTorch con CUDA: {str(e)}", "ERROR")
        return False

def generate_cuda_program():
    """Genera y compila un programa CUDA básico para verificar la instalación."""
    log("Generando programa CUDA de prueba...", "INFO")
    
    # Crear directorio temporal
    temp_dir = os.path.join(os.environ.get('TEMP', '.'), 'cuda_test')
    os.makedirs(temp_dir, exist_ok=True)
    
    # Archivo fuente CUDA
    cuda_file = os.path.join(temp_dir, 'vector_add.cu')
    
    # Código fuente CUDA
    cuda_code = """
#include <cstddef>
#include <stdio.h>

__global__ void vectorAdd(const float *A, const float *B, float *C, int numElements)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < numElements)
    {
        C[i] = A[i] + B[i];
    }
}

int main(void)
{
    // Print the vector length to be used, and compute its size
    int numElements = 50000;
    size_t size = numElements * sizeof(float);
    printf("[Vector addition of %d elements]\\n", numElements);

    // Allocate the host vectors
    float *h_A = (float *)malloc(size);
    float *h_B = (float *)malloc(size);
    float *h_C = (float *)malloc(size);

    // Initialize the host vectors
    for (int i = 0; i < numElements; ++i)
    {
        h_A[i] = rand()/(float)RAND_MAX;
        h_B[i] = rand()/(float)RAND_MAX;
    }

    // Allocate the device vectors
    float *d_A = NULL;
    float *d_B = NULL;
    float *d_C = NULL;
    cudaMalloc((void **)&d_A, size);
    cudaMalloc((void **)&d_B, size);
    cudaMalloc((void **)&d_C, size);

    // Copy the host vectors to device
    cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);

    // Launch the Vector Add CUDA Kernel
    int threadsPerBlock = 256;
    int blocksPerGrid = (numElements + threadsPerBlock - 1) / threadsPerBlock;
    printf("CUDA kernel launch with %d blocks of %d threads\\n", blocksPerGrid, threadsPerBlock);
    
    vectorAdd<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, numElements);
    
    // Check for errors
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "Failed to launch vectorAdd kernel (error code %s)!\\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    // Copy the device result vector to host
    cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);

    // Verify that the result vector is correct
    for (int i = 0; i < numElements; ++i)
    {
        if (fabs(h_A[i] + h_B[i] - h_C[i]) > 1e-5)
        {
            fprintf(stderr, "Result verification failed at element %d!\\n", i);
            exit(EXIT_FAILURE);
        }
    }
    
    printf("Test PASSED\\n");

    // Free device global memory
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);

    // Free host memory
    free(h_A);
    free(h_B);
    free(h_C);
    
    printf("Done\\n");
    return 0;
}
"""
    
    with open(cuda_file, 'w') as f:
        f.write(cuda_code)
    
    log(f"✅ Archivo CUDA creado en: {cuda_file}", "SUCCESS")
    
    # Compilar el programa CUDA
    log("Compilando programa CUDA...", "INFO")
    
    output_file = os.path.join(temp_dir, 'vector_add.exe')
    compile_cmd = f'nvcc "{cuda_file}" -o "{output_file}"'
    
    stdout, stderr, returncode = run_command(compile_cmd)
    if returncode != 0:
        log(f"❌ Error al compilar el programa CUDA: {stderr}", "ERROR")
        return False
    
    log("✅ Programa CUDA compilado correctamente", "SUCCESS")
    
    # Ejecutar el programa
    log("Ejecutando el programa CUDA...", "INFO")
    
    stdout, stderr, returncode = run_command(f'"{output_file}"')
    if returncode != 0:
        log(f"❌ Error al ejecutar el programa CUDA: {stderr}", "ERROR")
        return False
    
    log(f"✅ Programa CUDA ejecutado correctamente", "SUCCESS")
    log(f"Salida del programa:\n{stdout}", "INFO")
    
    if "Test PASSED" in stdout:
        log("✅ La prueba de CUDA fue exitosa!", "SUCCESS")
        return True
    else:
        log("❌ La prueba de CUDA falló", "ERROR")
        return False

def main():
    """Función principal que ejecuta todas las pruebas."""
    parser = argparse.ArgumentParser(description="Prueba la funcionalidad básica de CUDA")
    parser.add_argument("--driver", action="store_true", help="Solo probar el controlador NVIDIA")
    parser.add_argument("--nvcc", action="store_true", help="Solo probar el compilador NVCC")
    parser.add_argument("--pytorch", action="store_true", help="Solo probar PyTorch con CUDA")
    parser.add_argument("--compile", action="store_true", help="Solo compilar y ejecutar un programa CUDA básico")
    parser.add_argument("--all", action="store_true", help="Ejecutar todas las pruebas")
    
    args = parser.parse_args()
    
    # Si no se proporciona ningún argumento, ejecutar todas las pruebas
    if not any(vars(args).values()):
        args.all = True
    
    log("Iniciando pruebas de CUDA...", "INFO")
    print("\n" + "="*80 + "\n")
    
    # Verificar si se está ejecutando en Windows
    if platform.system() != "Windows":
        log("Este script está diseñado principalmente para Windows.", "WARNING")
    
    # Verificar Admin (no es obligatorio pero recomendado)
    if not is_admin():
        log("Se recomienda ejecutar este script como administrador para pruebas completas.", "WARNING")
    
    all_passed = True
    
    if args.driver or args.all:
        log("\nPRUEBA 1: Controlador NVIDIA", "INFO")
        print("-"*80)
        driver_passed = check_cuda_driver()
        all_passed = all_passed and driver_passed
        print("-"*80 + "\n")
    
    if args.nvcc or args.all:
        log("\nPRUEBA 2: Compilador CUDA (NVCC)", "INFO")
        print("-"*80)
        nvcc_passed = check_nvcc()
        all_passed = all_passed and nvcc_passed
        print("-"*80 + "\n")
    
    if args.pytorch or args.all:
        log("\nPRUEBA 3: PyTorch con CUDA", "INFO")
        print("-"*80)
        pytorch_passed = test_pytorch_cuda()
        all_passed = all_passed and pytorch_passed
        print("-"*80 + "\n")
    
    if args.compile or args.all:
        log("\nPRUEBA 4: Compilación y ejecución de programa CUDA", "INFO")
        print("-"*80)
        compile_passed = generate_cuda_program()
        all_passed = all_passed and compile_passed
        print("-"*80 + "\n")
    
    print("\n" + "="*80 + "\n")
    
    if all_passed:
        log("✅ TODAS LAS PRUEBAS DE CUDA PASARON CORRECTAMENTE!", "SUCCESS")
        log("Tu entorno está configurado correctamente para desarrollo con CUDA.", "SUCCESS")
    else:
        log("❌ ALGUNAS PRUEBAS DE CUDA FALLARON", "ERROR")
        log("Revisa los mensajes de error y consulta troubleshooting.md para resolver problemas.", "ERROR")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
