# Script para instalar entorno de desarrollo en Windows 11
# Instala Visual Studio 2022, Python 3.10, CUDA 12.4, cuDNN y componentes relacionados

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

# Configuración de versiones
$pythonVersion = "3.10.11"
$pythonUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"
$cudaVersion = "12.4.0"
$cudaUrl = "https://developer.download.nvidia.com/compute/cuda/$cudaVersion/local_installers/cuda_$($cudaVersion)_531.61_windows.exe"
$vsVersion = "2022"
$vsUrl = "https://aka.ms/vs/17/release/vs_community.exe"

# Función para registrar acciones en un archivo de log
function Log-Action {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path "install_log.txt" -Value $logMessage -Force
    
    switch ($Type) {
        "INFO" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Función para descargar archivos
function Download-File {
    param (
        [string]$Url,
        [string]$OutputFile
    )
    
    Log-Action "Descargando $Url a $OutputFile..." "INFO"
    
    try {
        # Crear cliente WebClient
        $webClient = New-Object System.Net.WebClient
        
        # Configurar TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Descargar archivo
        $webClient.DownloadFile($Url, $OutputFile)
        
        Log-Action "Descarga completa: $OutputFile" "SUCCESS"
        return $true
    }
    catch {
        Log-Action "Error al descargar desde $Url: $_" "ERROR"
        return $false
    }
}

# Crear carpeta temporal
$tempFolder = Join-Path $env:TEMP "DevEnvSetup"
if (-not (Test-Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

Log-Action "Iniciando instalación del entorno de desarrollo..." "INFO"

# Paso 1: Verificar conexión a Internet
Log-Action "Verificando conexión a Internet..." "INFO"
$internetConnection = Test-Connection -ComputerName www.microsoft.com -Count 1 -Quiet
if (-not $internetConnection) {
    Log-Action "No se detectó conexión a Internet. Este script requiere conexión a Internet para descargar los instaladores." "ERROR"
    exit 1
}
Log-Action "Conexión a Internet verificada." "SUCCESS"

# Paso 2: Verificar espacio en disco
Log-Action "Verificando espacio en disco disponible..." "INFO"
$systemDrive = (Get-Item $env:SystemDrive).Root.Name
$freeSpace = (Get-PSDrive $systemDrive[0]).Free
$requiredSpace = 50GB
if ($freeSpace -lt $requiredSpace) {
    Log-Action "Espacio insuficiente en el disco $systemDrive. Se requieren al menos 50 GB libres." "ERROR"
    exit 1
}
Log-Action "Espacio en disco verificado: $(($freeSpace / 1GB).ToString('N2')) GB disponibles." "SUCCESS"

# Paso 3: Instalación de Visual Studio 2022
Log-Action "Iniciando instalación de Visual Studio $vsVersion..." "INFO"

$vsInstallerPath = Join-Path $tempFolder "vs_community.exe"
$vsDownloaded = Download-File -Url $vsUrl -OutputFile $vsInstallerPath

if ($vsDownloaded) {
    Log-Action "Ejecutando instalador de Visual Studio $vsVersion..." "INFO"
    
    # Cargas de trabajo y componentes requeridos para IA/ML
    $vsWorkloads = @(
        "--add Microsoft.VisualStudio.Workload.NativeDesktop",
        "--add Microsoft.VisualStudio.Workload.Python",
        "--add Microsoft.VisualStudio.Workload.Data",
        "--add Microsoft.VisualStudio.Workload.ManagedDesktop",
        "--add Microsoft.VisualStudio.Workload.NativeCrossPlat",
        "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "--add Microsoft.VisualStudio.Component.Windows10SDK.20348",
        "--add Microsoft.VisualStudio.Component.VC.ATLMFC",
        "--includeRecommended"
    ) -join " "
    
    $vsInstallArgs = "--passive --norestart --wait $vsWorkloads"
    
    try {
        $process = Start-Process -FilePath $vsInstallerPath -ArgumentList $vsInstallArgs -PassThru -Wait
        if ($process.ExitCode -eq 0) {
            Log-Action "Visual Studio $vsVersion instalado correctamente." "SUCCESS"
        }
        else {
            Log-Action "Error al instalar Visual Studio $vsVersion. Código de salida: $($process.ExitCode)" "ERROR"
        }
    }
    catch {
        Log-Action "Error al ejecutar el instalador de Visual Studio: $_" "ERROR"
    }
}
else {
    Log-Action "No se pudo descargar Visual Studio $vsVersion." "ERROR"
}

# Paso 4: Instalación de Python
Log-Action "Iniciando instalación de Python $pythonVersion..." "INFO"

$pythonInstallerPath = Join-Path $tempFolder "python-$pythonVersion-amd64.exe"
$pythonDownloaded = Download-File -Url $pythonUrl -OutputFile $pythonInstallerPath

if ($pythonDownloaded) {
    Log-Action "Ejecutando instalador de Python $pythonVersion..." "INFO"
    
    # Argumentos para instalación desatendida, con pip, incluir Python en PATH
    $pythonInstallArgs = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_pip=1 Include_doc=0"
    
    try {
        $process = Start-Process -FilePath $pythonInstallerPath -ArgumentList $pythonInstallArgs -PassThru -Wait
        if ($process.ExitCode -eq 0) {
            Log-Action "Python $pythonVersion instalado correctamente." "SUCCESS"
            
            # Refrescar la variable de entorno PATH para que esta sesión reconozca Python
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            # Verificar la instalación
            $pythonPath = & where.exe python 2>$null
            if ($pythonPath) {
                $pythonVer = & python --version 2>&1
                Log-Action "Python verificado: $pythonVer" "SUCCESS"
                
                # Instalar/actualizar pip y setuptools
                Log-Action "Actualizando pip y setuptools..." "INFO"
                $process = Start-Process -FilePath "python" -ArgumentList "-m pip install --upgrade pip setuptools wheel" -PassThru -Wait
                Log-Action "Pip y setuptools actualizados." "SUCCESS"
            }
            else {
                Log-Action "Python instalado pero no encontrado en PATH. Puede ser necesario reiniciar." "WARNING"
            }
        }
        else {
            Log-Action "Error al instalar Python $pythonVersion. Código de salida: $($process.ExitCode)" "ERROR"
        }
    }
    catch {
        Log-Action "Error al ejecutar el instalador de Python: $_" "ERROR"
    }
}
else {
    Log-Action "No se pudo descargar Python $pythonVersion." "ERROR"
}

# Paso 5: Instalación de CUDA
Log-Action "Iniciando instalación de CUDA $cudaVersion..." "INFO"

$cudaInstallerPath = Join-Path $tempFolder "cuda_installer.exe"
$cudaDownloaded = Download-File -Url $cudaUrl -OutputFile $cudaInstallerPath

if ($cudaDownloaded) {
    Log-Action "Ejecutando instalador de CUDA $cudaVersion..." "INFO"
    
    # Argumentos para instalación silenciosa
    $cudaInstallArgs = "-s"
    
    try {
        $process = Start-Process -FilePath $cudaInstallerPath -ArgumentList $cudaInstallArgs -PassThru -Wait
        if ($process.ExitCode -eq 0) {
            Log-Action "CUDA $cudaVersion instalado correctamente." "SUCCESS"
            
            # Configurar variables de entorno para CUDA
            [Environment]::SetEnvironmentVariable("CUDA_PATH", "$env:ProgramFiles\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))", "Machine")
            [Environment]::SetEnvironmentVariable("CUDA_PATH_V$($cudaVersion.Replace('.', '_'))", "$env:ProgramFiles\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))", "Machine")
            
            # Agregar rutas de CUDA a PATH
            $cudaBinPath = "$env:ProgramFiles\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))\bin"
            $cudaLibPath = "$env:ProgramFiles\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))\libnvvp"
            
            $machPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($machPath -notlike "*$cudaBinPath*") {
                [Environment]::SetEnvironmentVariable("Path", "$machPath;$cudaBinPath;$cudaLibPath", "Machine")
                Log-Action "Rutas de CUDA agregadas a la variable PATH del sistema." "SUCCESS"
                
                # Refrescar la variable de entorno PATH para esta sesión
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
            
            # Verificar la instalación
            $nvccPath = & where.exe nvcc 2>$null
            if ($nvccPath) {
                $nvccVersion = & nvcc --version 2>&1
                Log-Action "CUDA verificado: $nvccVersion" "SUCCESS"
            }
            else {
                Log-Action "CUDA instalado pero nvcc no encontrado en PATH. Puede ser necesario reiniciar." "WARNING"
            }
        }
        else {
            Log-Action "Error al instalar CUDA $cudaVersion. Código de salida: $($process.ExitCode)" "ERROR"
        }
    }
    catch {
        Log-Action "Error al ejecutar el instalador de CUDA: $_" "ERROR"
    }
}
else {
    Log-Action "No se pudo descargar CUDA $cudaVersion." "ERROR"
}

# Paso 6: Descargar e Instalar cuDNN
Log-Action "Importante: No se puede automatizar la descarga de cuDNN ya que requiere inicio de sesión en el portal de NVIDIA Developer." "WARNING"
Log-Action "Por favor, descarga manualmente cuDNN compatible con CUDA $cudaVersion desde https://developer.nvidia.com/cudnn" "INFO"
Log-Action "Una vez descargado, sigue estas instrucciones para instalarlo:" "INFO"
Log-Action "1. Extrae el archivo cuDNN descargado" "INFO"
Log-Action "2. Copia los archivos a las carpetas correspondientes en CUDA" "INFO"
Log-Action "   - Copia bin\*.dll a C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))\bin" "INFO"
Log-Action "   - Copia include\*.h a C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))\include" "INFO"
Log-Action "   - Copia lib\x64\*.lib a C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($cudaVersion.Substring(0, 4))\lib\x64" "INFO"
Log-Action "Alternativamente, puedes usar el script de ayuda que hemos incluido: setup_cudnn.ps1" "INFO"

# Paso 7: Instalar bibliotecas Python para IA/ML
Log-Action "Instalando bibliotecas Python para IA/ML..." "INFO"

# Verificar que Python esté en PATH
$pythonPath = & where.exe python 2>$null
if (-not $pythonPath) {
    Log-Action "Python no encontrado en PATH. Revisa la instalación de Python." "ERROR"
}
else {
    $requirementsFile = Join-Path $PSScriptRoot "requirements.txt"
    if (Test-Path $requirementsFile) {
        Log-Action "Instalando paquetes desde requirements.txt..." "INFO"
        $process = Start-Process -FilePath "python" -ArgumentList "-m pip install -r `"$requirementsFile`"" -PassThru -Wait
        if ($process.ExitCode -eq 0) {
            Log-Action "Paquetes instalados correctamente desde requirements.txt." "SUCCESS"
        }
        else {
            Log-Action "Error al instalar paquetes desde requirements.txt. Código de salida: $($process.ExitCode)" "ERROR"
        }
    }
    else {
        Log-Action "Instalando paquetes comunes para IA/ML..." "INFO"
        
        # Instalar numpy, scipy, matplotlib (dependencias comunes)
        $process = Start-Process -FilePath "python" -ArgumentList "-m pip install numpy scipy matplotlib pandas scikit-learn jupyter" -PassThru -Wait
        Log-Action "Paquetes base instalados." "SUCCESS"
        
        # Instalar PyTorch con soporte CUDA
        Log-Action "Instalando PyTorch con soporte CUDA..." "INFO"
        $process = Start-Process -FilePath "python" -ArgumentList "-m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124" -PassThru -Wait
        Log-Action "PyTorch instalado." "SUCCESS"
        
        # Instalar bibliotecas para NLP y LLM
        Log-Action "Instalando bibliotecas para NLP y LLM..." "INFO"
        $process = Start-Process -FilePath "python" -ArgumentList "-m pip install transformers datasets huggingface_hub tokenizers" -PassThru -Wait
        Log-Action "Bibliotecas de NLP instaladas." "SUCCESS"
        
        # Crear requirements.txt para referencia futura
        Log-Action "Generando requirements.txt con los paquetes instalados..." "INFO"
        $process = Start-Process -FilePath "python" -ArgumentList "-m pip freeze > requirements.txt" -PassThru -Wait
        Log-Action "requirements.txt generado." "SUCCESS"
    }
    
    # Verificar la instalación de PyTorch con CUDA
    Log-Action "Verificando que PyTorch pueda detectar CUDA..." "INFO"
    $pythonCode = @"
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA disponible: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"Dispositivos CUDA: {torch.cuda.device_count()}")
    print(f"Nombre del dispositivo CUDA: {torch.cuda.get_device_name(0)}")
    print(f"Versión de CUDA: {torch.version.cuda}")
else:
    print("CUDA no está disponible para PyTorch")
"@
    
    $pythonCode | Out-File -FilePath (Join-Path $tempFolder "check_pytorch.py") -Encoding utf8
    $process = Start-Process -FilePath "python" -ArgumentList (Join-Path $tempFolder "check_pytorch.py") -PassThru -Wait -RedirectStandardOutput (Join-Path $tempFolder "pytorch_output.txt")
    
    $pytorchOutput = Get-Content -Path (Join-Path $tempFolder "pytorch_output.txt") -Raw
    Log-Action "Resultado de verificación de PyTorch:" "INFO"
    Log-Action $pytorchOutput "INFO"
    
    if ($pytorchOutput -like "*CUDA disponible: True*") {
        Log-Action "PyTorch detectó correctamente CUDA." "SUCCESS"
    }
    else {
        Log-Action "PyTorch no pudo detectar CUDA. Revisa la instalación de CUDA y PyTorch." "WARNING"
    }
}

# Paso 8: Resumen de instalación
Log-Action "Instalación completada." "SUCCESS"
Log-Action "Componentes instalados:" "INFO"
Log-Action "- Visual Studio $vsVersion Community" "INFO"
Log-Action "- Python $pythonVersion" "INFO"
Log-Action "- CUDA $cudaVersion" "INFO"
Log-Action "- Bibliotecas de Python para IA/ML" "INFO"
Log-Action "Pendiente: Instalación manual de cuDNN (ver instrucciones)" "WARNING"

Log-Action "Se recomienda reiniciar el sistema para completar la configuración del entorno." "INFO"

Write-Host "`nInstalación completada. Por favor, reinicia el sistema para completar la configuración." -ForegroundColor Green