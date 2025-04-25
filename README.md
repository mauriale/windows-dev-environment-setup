# Configuración de Entorno de Desarrollo para IA/ML en Windows 11

Este repositorio contiene scripts para configurar un entorno de desarrollo limpio y coherente para IA/ML en Windows 11, solucionando problemas de compatibilidad entre Visual Studio, CUDA, Python y otros componentes.

## Componentes que se instalarán

- Visual Studio Community 2022 con cargas de trabajo necesarias
- Python 3.10 (versión estable y compatible con PyTorch)
- CUDA 12.4 para desarrollo con GPU
- cuDNN compatible con CUDA 12.4
- PyTorch con soporte para CUDA
- Bibliotecas comunes para ML/NLP/LLM

## Requisitos previos

- Windows 11
- Derechos de administrador
- Conexión a Internet
- Tarjeta gráfica NVIDIA compatible con CUDA

## Instrucciones de uso

### Opción 1: Script todo-en-uno (Recomendado)

1. Clona este repositorio
2. Abre PowerShell como administrador
3. Ejecuta: `python setup_environment.py --full`

El script manejará todo el proceso, incluyendo:
- Verificación de requisitos
- Limpieza del sistema
- Instalación de componentes
- Verificación de la instalación
- Configuración de variables de entorno

### Opción 2: Ejecución paso a paso

Si prefieres ejecutar los pasos manualmente:

1. **Limpieza del sistema**:
   ```powershell
   .\cleanup.ps1
   ```

2. **Instalación de componentes**:
   ```powershell
   .\install.ps1
   ```

3. **Verificación de instalación**:
   ```powershell
   python verify.py
   ```

## Solución de problemas

Si encuentras problemas durante la instalación, consulta el archivo `troubleshooting.md` para soluciones comunes.

## Precaución

- **¡IMPORTANTE!** El script de limpieza eliminará todas las versiones de Visual Studio, Python, CUDA y componentes relacionados.
- **Haz una copia de seguridad de tus proyectos y datos importantes antes de ejecutar estos scripts.**
- Si tienes configuraciones personalizadas que deseas mantener, revisa y modifica los scripts según sea necesario antes de ejecutarlos.