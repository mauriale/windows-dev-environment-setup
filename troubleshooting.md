# Solución de Problemas

Este documento contiene soluciones para problemas comunes que pueden surgir durante la configuración del entorno de desarrollo para IA/ML en Windows 11.

## Problemas Generales

### Error de permisos al ejecutar scripts

**Problema**: PowerShell muestra errores de ejecución de scripts no permitida.

**Solución**: 
1. Abre PowerShell como administrador
2. Ejecuta: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. Confirma con "S"
4. Intenta ejecutar el script nuevamente

### El script se cierra inmediatamente

**Problema**: Al hacer doble clic en un script PowerShell, se abre y cierra inmediatamente.

**Solución**:
1. Abre PowerShell como administrador
2. Navega a la carpeta que contiene los scripts (`cd ruta\a\la\carpeta`)
3. Ejecuta el script con `.\nombre_del_script.ps1`

## Problemas de Limpieza

### No se pueden desinstalar programas

**Problema**: Algunos programas no se desinstalan correctamente mediante el script de limpieza.

**Solución**:
1. Desinstala manualmente los programas desde "Programas y características" en el Panel de control
2. Elimina manualmente las carpetas residuales:
   - Para Visual Studio: `C:\Program Files\Microsoft Visual Studio` y `C:\Program Files (x86)\Microsoft Visual Studio`
   - Para Python: `C:\Program Files\Python*` y `C:\Users\<usuario>\AppData\Local\Programs\Python`
   - Para CUDA: `C:\Program Files\NVIDIA GPU Computing Toolkit`

### Variables de entorno no se limpian correctamente

**Problema**: Algunas variables de entorno persisten después de la limpieza.

**Solución**:
1. Abre "Editar las variables de entorno del sistema" (busca en el menú Inicio)
2. En Variables de entorno, revisa y elimina manualmente las entradas relacionadas con:
   - Python
   - CUDA
   - Visual Studio

## Problemas de Instalación

### Visual Studio no se instala correctamente

**Problema**: El instalador de Visual Studio falla o no instala todas las cargas de trabajo.

**Solución**:
1. Descarga manualmente el instalador de Visual Studio 2022 Community desde https://visualstudio.microsoft.com/
2. Ejecuta el instalador y selecciona las siguientes cargas de trabajo:
   - Desarrollo de escritorio con C++
   - Desarrollo de Python
   - Desarrollo de escritorio de .NET
   - Desarrollo multiplataforma con C++
3. Asegúrate de incluir estos componentes individuales:
   - Herramientas de compilación de MSVC para x64/x86
   - Windows 10 SDK
   - Bibliotecas ATL/MFC

### Python no se instala correctamente

**Problema**: Python no se instala o no se añade al PATH.

**Solución**:
1. Descarga Python 3.10.x manualmente desde https://www.python.org/downloads/
2. Durante la instalación, selecciona "Add Python to PATH"
3. Selecciona "Install for all users"
4. Después de la instalación, verifica con `python --version` en una nueva ventana de PowerShell

### CUDA no se instala correctamente

**Problema**: Errores durante la instalación de CUDA o CUDA no funciona con PyTorch.

**Solución**:
1. Asegúrate de tener los controladores NVIDIA más recientes instalados
2. Descarga CUDA 12.4 manualmente desde https://developer.nvidia.com/cuda-downloads
3. Instala solo los componentes necesarios:
   - CUDA Runtime and Development
   - Visual Studio Integration
4. Después de la instalación, reinicia el sistema
5. Verifica la instalación con `nvcc --version`

### cuDNN no se instala correctamente

**Problema**: cuDNN no se configura correctamente después de la instalación.

**Solución**:
1. Verifica que estás utilizando una versión de cuDNN compatible con CUDA 12.4
2. Copia manualmente los archivos a las carpetas correctas:
   - Copia los archivos `.dll` a `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin`
   - Copia los archivos `.h` a `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\include`
   - Copia los archivos `.lib` a `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\lib\x64`
3. Reinicia el sistema después de copiar los archivos

## Problemas con PyTorch

### PyTorch no detecta CUDA

**Problema**: PyTorch indica que CUDA no está disponible, aunque CUDA está instalado.

**Solución**:
1. Verifica la versión de CUDA instalada: `nvcc --version`
2. Reinstala PyTorch con la versión correcta de CUDA:
   ```
   pip uninstall torch torchvision torchaudio
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
   ```
3. Verifica con:
   ```python
   import torch
   print(torch.cuda.is_available())
   print(torch.version.cuda)
   ```

### Errores al importar bibliotecas Python

**Problema**: Errores al importar NumPy, SciPy u otras bibliotecas.

**Solución**:
1. Actualiza pip: `python -m pip install --upgrade pip`
2. Instala las bibliotecas individualmente con el flag --force-reinstall:
   ```
   pip install --force-reinstall numpy scipy matplotlib pandas scikit-learn
   ```
3. Si persisten los problemas, verifica conflictos de dependencias:
   ```
   pip check
   ```

## Problemas de Compatibilidad

### Incompatibilidad entre Visual Studio y CUDA

**Problema**: Compilación de código CUDA falla con errores de Visual Studio.

**Solución**:
1. Verifica que tienes instalada la versión de Visual Studio compatible con CUDA 12.4
2. Asegúrate de tener instalado el componente "MSVC v143 - VS 2022 C++ x64/x86 build tools"
3. Establece las variables de entorno correctamente:
   ```
   setx CUDA_PATH "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"
   ```

### Incompatibilidad entre Python y PyTorch

**Problema**: PyTorch no es compatible con la versión de Python instalada.

**Solución**:
1. Verifica la versión de Python con `python --version`
2. Si tienes Python 3.11 o superior, considera instalar Python 3.10.x (que tiene mejor compatibilidad con PyTorch)
3. Usa ambientes virtuales para mantener múltiples versiones de Python:
   ```
   python -m venv venv_torch
   venv_torch\Scripts\activate
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
   ```

## Problemas de Rendimiento

### Bajo rendimiento de GPU

**Problema**: El rendimiento de la GPU es inferior al esperado.

**Solución**:
1. Actualiza los controladores de NVIDIA a la última versión
2. Verifica que no estén ejecutándose otras aplicaciones que consuman GPU
3. Configura PyTorch para usar la GPU correcta si tienes múltiples:
   ```python
   import torch
   torch.cuda.set_device(0)  # Utiliza la primera GPU
   ```
4. Verifica la temperatura de la GPU con `nvidia-smi -l 1` para monitorear posible throttling térmico