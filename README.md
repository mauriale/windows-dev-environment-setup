# Configuración de Entorno de Desarrollo para IA/ML en Windows 11

Este repositorio contiene scripts automatizados para configurar un entorno de desarrollo limpio y coherente para Inteligencia Artificial y Machine Learning en Windows 11, solucionando problemas de compatibilidad entre Visual Studio, CUDA, Python y otros componentes.

## 🚀 Características Principales

- **Limpieza Completa**: Eliminación segura de instalaciones anteriores para evitar conflictos
- **Verificación Exhaustiva**: Comprobación de limpieza e instalación correcta
- **Instalación Automatizada**: Componentes configurados con versiones compatibles
- **Solución de Problemas**: Guía detallada para resolver inconvenientes comunes
- **Preparado para GPU**: Soporte óptimo para CUDA y desarrollo con aceleración GPU

## 📋 Componentes que se instalarán

- **Visual Studio Community 2022** con cargas de trabajo necesarias:
  - Desarrollo de escritorio con C++
  - Desarrollo de Python
  - Desarrollo de datos
  - Desarrollo multiplataforma con C++
  
- **Python 3.10.11** (versión estable y compatible con PyTorch)

- **CUDA 12.4** para desarrollo con GPU:
  - Herramientas de compilación
  - Configuración de PATH y variables de entorno
  
- **cuDNN** compatible con CUDA 12.4 (requiere descarga manual)

- **Bibliotecas Python para IA/ML**:
  - PyTorch con soporte CUDA
  - NumPy, SciPy, Pandas, Matplotlib, Scikit-learn
  - Hugging Face Transformers y Datasets
  - Herramientas de procesamiento de datos y desarrollo

## 💻 Requisitos previos

- Windows 11 (64 bits)
- Derechos de administrador
- Conexión a Internet
- Tarjeta gráfica NVIDIA compatible con CUDA
- Al menos 50 GB de espacio libre en disco
- Al menos 8 GB de RAM (16 GB recomendado)

## 🔧 Instrucciones de uso

### Opción 1: Script todo-en-uno (Recomendado)

1. Clona este repositorio:
   ```bash
   git clone https://github.com/mauriale/windows-dev-environment-setup.git
   cd windows-dev-environment-setup
   ```

2. Abre PowerShell como administrador y ejecuta:
   ```powershell
   python setup_environment.py --full
   ```

El script manejará todo el proceso automáticamente con las pausas necesarias.

### Opción 2: Ejecución paso a paso

Si prefieres ejecutar los pasos manualmente:

1. **Limpieza del sistema**:
   ```powershell
   .\cleanup.ps1
   ```

2. **Verificación de la limpieza**:
   ```powershell
   .\verify_cleanup.ps1
   ```

3. **Instalación de componentes**:
   ```powershell
   .\install.ps1
   ```

4. **Configuración de cuDNN** (requiere descarga manual):
   ```powershell
   .\setup_cudnn.ps1
   ```

5. **Verificación de instalación**:
   ```powershell
   python verify.py
   ```

## 📚 Explicación detallada de los scripts

### cleanup.ps1
Script de PowerShell que desinstala completamente todos los componentes conflictivos:
- Cierra procesos en ejecución relacionados con los componentes
- Desinstala Visual Studio, Python, CUDA y componentes relacionados
- Limpia variables de entorno y PATH
- Elimina carpetas residuales y entradas de registro

### verify_cleanup.ps1
Script de PowerShell que verifica exhaustivamente que la limpieza se ha completado:
- Comprueba instalaciones residuales de Visual Studio, Python y CUDA
- Verifica variables de entorno y PATH
- Comprueba carpetas y registros
- Genera un informe detallado con recomendaciones específicas

### install.ps1
Script de PowerShell que instala y configura todos los componentes necesarios:
- Descarga e instala Visual Studio 2022 con las cargas de trabajo especificadas
- Instala Python 3.10.11 y configura PATH
- Descarga e instala CUDA 12.4
- Configura variables de entorno
- Instala bibliotecas Python esenciales para IA/ML

### setup_cudnn.ps1
Script auxiliar que facilita la instalación de cuDNN:
- Guía al usuario para descargar el paquete cuDNN adecuado
- Extrae archivos automáticamente (compatible con ZIP y TAR.GZ)
- Copia los archivos a las ubicaciones correctas de CUDA
- Configura variables de entorno si es necesario

### verify.py
Script de Python que realiza verificaciones exhaustivas del entorno:
- Comprueba la correcta instalación de Visual Studio y sus componentes
- Verifica Python y sus bibliotecas
- Comprueba CUDA, nvcc y cuDNN
- Verifica que PyTorch pueda acceder a la GPU
- Genera un informe detallado del estado del sistema

### setup_environment.py
Script orquestador en Python que integra todo el proceso:
- Interfaz unificada para todo el flujo de trabajo
- Control granular de cada fase del proceso
- Gestión de errores y reintentos
- Recomendaciones personalizadas

## ⚙️ Opciones del script setup_environment.py

```
python setup_environment.py --help
```

| Opción | Descripción |
|--------|-------------|
| --requirements | Muestra los requisitos del sistema |
| --clean | Ejecuta solo el proceso de limpieza |
| --verify-cleanup | Verifica que la limpieza se realizó correctamente |
| --install | Ejecuta solo el proceso de instalación |
| --cudnn | Ejecuta solo la configuración de cuDNN |
| --verify | Ejecuta solo el proceso de verificación |
| --full | Ejecuta todo el proceso completo |

## 🔍 Solución de problemas

El repositorio incluye un archivo `troubleshooting.md` con soluciones para problemas comunes:

- **Problemas generales**: Permisos de PowerShell, ejecución de scripts
- **Problemas de limpieza**: Componentes difíciles de desinstalar
- **Problemas de instalación**: Errores específicos para cada componente
- **Problemas con PyTorch**: Detección de CUDA, importación de bibliotecas
- **Problemas de compatibilidad**: Entre Visual Studio, CUDA y Python
- **Problemas de rendimiento**: Optimización de GPU, controladores

## ⚠️ Precaución

- **¡IMPORTANTE!** El script de limpieza eliminará todas las versiones existentes de Visual Studio, Python, CUDA y componentes relacionados.
- **Haz una copia de seguridad de tus proyectos y datos importantes antes de ejecutar estos scripts.**
- Si tienes configuraciones personalizadas que deseas mantener, revisa y modifica los scripts según sea necesario.

## 📋 Flujo de trabajo recomendado

1. Hacer copia de seguridad de datos importantes
2. Verificar los requisitos del sistema:
   ```powershell
   python setup_environment.py --requirements
   ```
3. Limpiar el sistema:
   ```powershell
   python setup_environment.py --clean
   ```
4. Verificar la limpieza:
   ```powershell
   python setup_environment.py --verify-cleanup
   ```
5. **Reiniciar el sistema**
6. Instalar componentes:
   ```powershell
   python setup_environment.py --install
   ```
7. Descargar cuDNN desde [NVIDIA Developer](https://developer.nvidia.com/cudnn) (requiere cuenta gratuita)
8. Configurar cuDNN:
   ```powershell
   python setup_environment.py --cudnn
   ```
9. Verificar la instalación:
   ```powershell
   python setup_environment.py --verify
   ```

## 🛠️ Personalización

Los scripts están diseñados para ser fácilmente personalizables:

- Modifica las versiones de los componentes en `install.ps1`
- Ajusta las bibliotecas Python en `requirements.txt`
- Adapta los pasos de limpieza en `cleanup.ps1` según tus necesidades

## 📊 Verificación de PyTorch con CUDA

Después de la instalación, puedes verificar que PyTorch detecta correctamente CUDA:

```python
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA disponible: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"Dispositivos CUDA: {torch.cuda.device_count()}")
    print(f"Nombre del dispositivo CUDA: {torch.cuda.get_device_name(0)}")
    print(f"Versión de CUDA: {torch.version.cuda}")
```

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Si encuentras errores o tienes mejoras, por favor:

1. Crea un issue para discutir el cambio propuesto
2. Envía un Pull Request con tus mejoras
3. Mantén el mismo estilo de código y documentación

## 📜 Licencia

Este proyecto está disponible bajo la licencia MIT. Consulta el archivo LICENSE para más detalles.