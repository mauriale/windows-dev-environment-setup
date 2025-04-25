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
- Verificación de la limpieza
- Instalación de componentes
- Verificación de la instalación
- Configuración de variables de entorno

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

## Explicación de los scripts

### cleanup.ps1
Script de PowerShell que desinstala completamente todos los componentes conflictivos:
- Visual Studio y componentes relacionados
- Python y bibliotecas
- CUDA, cuDNN y componentes NVIDIA
- Limpia variables de entorno
- Elimina carpetas residuales
- Limpia registros

### verify_cleanup.ps1
Script de PowerShell que verifica que la limpieza se ha realizado correctamente:
- Verifica que no quedan instalaciones de Visual Studio
- Verifica que no quedan instalaciones de Python
- Verifica que no quedan instalaciones de CUDA/cuDNN
- Verifica que las variables de entorno están limpias
- Verifica que los registros están limpios
- Genera un informe detallado con recomendaciones

Este script es crucial ejecutarlo después de la limpieza y antes de la instalación para asegurar que no habrá conflictos.

### install.ps1
Script de PowerShell que instala todos los componentes necesarios:
- Visual Studio 2022 Community con las cargas de trabajo necesarias
- Python 3.10 con pip y bibliotecas esenciales
- CUDA 12.4 para desarrollo con GPU
- Configura variables de entorno y rutas

### setup_cudnn.ps1
Script auxiliar para instalar cuDNN después de descargarlo manualmente:
- Extrae el archivo cuDNN descargado
- Copia los archivos a las ubicaciones correctas de CUDA
- Configura variables de entorno si es necesario

### verify.py
Script de Python que verifica que todos los componentes se han instalado correctamente:
- Verifica Visual Studio y sus cargas de trabajo
- Verifica Python y sus bibliotecas
- Verifica CUDA, nvcc y soporte para GPU
- Verifica PyTorch con soporte CUDA
- Verifica bibliotecas adicionales para ML/NLP/LLM

### setup_environment.py
Script orquestador en Python que puede ejecutar todo el proceso desde un único comando:
- Permite ejecutar pasos específicos o todo el proceso
- Verifica prerrequisitos
- Maneja errores y excepciones
- Ofrece recomendaciones según los resultados

## Opciones del script setup_environment.py

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

## Solución de problemas

Si encuentras problemas durante la instalación, consulta el archivo `troubleshooting.md` para soluciones comunes.

## Precaución

- **¡IMPORTANTE!** El script de limpieza eliminará todas las versiones de Visual Studio, Python, CUDA y componentes relacionados.
- **Haz una copia de seguridad de tus proyectos y datos importantes antes de ejecutar estos scripts.**
- Si tienes configuraciones personalizadas que deseas mantener, revisa y modifica los scripts según sea necesario antes de ejecutarlos.

## Flujo de trabajo recomendado

1. Hacer copia de seguridad de datos importantes
2. Ejecutar `python setup_environment.py --requirements` para verificar requisitos
3. Ejecutar `python setup_environment.py --clean` para limpiar el sistema
4. Ejecutar `python setup_environment.py --verify-cleanup` para confirmar la limpieza
5. Reiniciar el sistema
6. Ejecutar `python setup_environment.py --install` para instalar componentes
7. Descargar cuDNN manualmente desde el sitio de NVIDIA
8. Ejecutar `python setup_environment.py --cudnn` para configurar cuDNN
9. Ejecutar `python setup_environment.py --verify` para verificar la instalación

Alternativamente, ejecutar `python setup_environment.py --full` para realizar todo el proceso en un solo paso (con las pausas necesarias).