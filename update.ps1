# Script para actualizar componentes del entorno de desarrollo sin reinstalación completa
# Actualiza Python, CUDA, bibliotecas y componentes relacionados

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

# Definir la ruta del archivo de log
$logFilePath = "update_log.txt"

# Iniciar el archivo de log con encabezado
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logHeader = @"
===========================================================================
            ACTUALIZACIÓN DE ENTORNO DE DESARROLLO - LOG DE EJECUCIÓN
===========================================================================
Inicio: $timestamp
Sistema: $([System.Environment]::OSVersion.VersionString)
Usuario: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
===========================================================================

"@
Set-Content -Path $logFilePath -Value $logHeader -Force

# Función para registrar acciones en un archivo de log y en la consola
function Log-Action {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path $logFilePath -Value $logMessage -Force
    
    switch ($Type) {
        "INFO" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Función para pedir confirmación antes de continuar
function Confirm-Action {
    param (
        [string]$Message
    )
    
    Write-Host "$Message (S/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    return $response -eq "S"
}

# Función para descargar archivos
function Download-File {
    param (
        [string]$Url,
        [string]$OutputFile,
        [int]$RetryCount = 3,
        [int]$RetryDelay = 5
    )
    
    Log-Action "Descargando $Url a $OutputFile..." "INFO"
    
    $retryAttempt = 0
    $success = $false
    
    while (-not $success -and $retryAttempt -lt $RetryCount) {
        try {
            # Crear cliente WebClient
            $webClient = New-Object System.Net.WebClient
            
            # Configurar TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            # Descargar archivo
            $webClient.DownloadFile($Url, $OutputFile)
            
            Log-Action "Descarga completa: $OutputFile" "SUCCESS"
            $success = $true
        }
        catch {
            $retryAttempt++
            Log-Action "Error al descargar desde $Url (intento $retryAttempt de $RetryCount): $_" "ERROR"
            
            if ($retryAttempt -lt $RetryCount) {
                Log-Action "Reintentando en $RetryDelay segundos..." "INFO"
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }
    
    return $success
}

# Función para ejecutar comandos con registro
function Execute-Command {
    param (
        [string]$Command,
        [string]$Description,
        [int]$TimeoutSeconds = 0,
        [bool]$CaptureOutput = $true
    )
    
    Log-Action "Ejecutando: $Command" "INFO"
    Log-Action $Description "INFO"
    
    try {
        if ($TimeoutSeconds -gt 0) {
            Log-Action "Timeout configurado: $TimeoutSeconds segundos" "INFO"
        }
        
        $startTime = Get-Date
        
        if ($CaptureOutput) {
            $output = Invoke-Expression -Command $Command -ErrorVariable errorMsg 2>&1
            
            if ($output) {
                foreach ($line in $output) {
                    Log-Action "  > $line" "INFO"
                }
            }
        } 
        else {
            Invoke-Expression -Command $Command -ErrorVariable errorMsg
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Log-Action "Comando ejecutado correctamente (duración: $([Math]::Round($duration, 2)) segundos)" "SUCCESS"
        return $true
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Log-Action "Error al ejecutar el comando (duración: $([Math]::Round($duration, 2)) segundos): $_" "ERROR"
        if ($errorMsg) {
            Log-Action "Detalles del error: $errorMsg" "ERROR"
        }
        return $false
    }
}

# Función para detectar versiones instaladas
function Detect-InstalledComponents {
    Log-Action "Detectando componentes instalados..." "INFO"
    
    $components = @{}
    
    # [Resto del código de detección...]
    # Por brevedad, asumimos que esta función ya está completa
    
    return $components
}

# Función para actualizar Python
function Update-Python {
    param (
        [string]$TargetVersion = "3.10.11",
        [bool]$ForceReinstall = $false
    )
    
    # [Resto del código de actualización de Python...]
    # Por brevedad, asumimos que esta función ya está completa
}

# Función para actualizar CUDA
function Update-CUDA {
    param (
        [string]$TargetVersion = "12.4.0",
        [bool]$ForceReinstall = $false
    )
    
    # [Resto del código de actualización de CUDA...]
    # Por brevedad, asumimos que esta función ya está completa
}

# Función para actualizar PyTorch
function Update-PyTorch {
    param (
        [string]$CudaVersion = "12.4"
    )
    
    # [Resto del código de actualización de PyTorch...]
    # Por brevedad, asumimos que esta función ya está completa
}

# Función para actualizar bibliotecas Python desde requirements.txt
function Update-PythonPackages {
    # [Resto del código de actualización de paquetes Python...]
    # Por brevedad, asumimos que esta función ya está completa
}

# Función para actualizar Visual Studio
function Update-VisualStudio {
    param (
        [bool]$UpdateOnly = $true
    )
    
    # [Resto del código de actualización de Visual Studio...]
    # Por brevedad, asumimos que esta función ya está completa
}

# Función principal para ejecutar el proceso de actualización
function Start-UpdateProcess {
    param (
        [switch]$UpdatePython = $false,
        [switch]$UpdateCUDA = $false,
        [switch]$UpdatePyTorch = $false,
        [switch]$UpdateVisualStudio = $false,
        [switch]$UpdatePackages = $false,
        [switch]$All = $false,
        
        [string]$PythonVersion = "3.10.11",
        [string]$CudaVersion = "12.4.0",
        [bool]$Force = $false
    )
    
    # Mostrar componentes instalados
    $installedComponents = Detect-InstalledComponents
    
    # Determinar qué actualizar
    if ($All) {
        $UpdatePython = $true
        $UpdateCUDA = $true
        $UpdatePyTorch = $true
        $UpdateVisualStudio = $true
        $UpdatePackages = $true
    }
    
    # Actualizar Python si se solicita
    if ($UpdatePython) {
        Log-Action "ACTUALIZANDO PYTHON $PythonVersion" "INFO"
        $pythonSuccess = Update-Python -TargetVersion $PythonVersion -ForceReinstall $Force
        if ($pythonSuccess) {
            Log-Action "Python actualizado correctamente a la versión $PythonVersion." "SUCCESS"
        } else {
            Log-Action "Hubo problemas al actualizar Python." "ERROR"
        }
    }
    
    # Actualizar CUDA si se solicita
    if ($UpdateCUDA) {
        Log-Action "ACTUALIZANDO CUDA $CudaVersion" "INFO"
        $cudaSuccess = Update-CUDA -TargetVersion $CudaVersion -ForceReinstall $Force
        if ($cudaSuccess) {
            Log-Action "CUDA actualizado correctamente a la versión $CudaVersion." "SUCCESS"
        } else {
            Log-Action "Hubo problemas al actualizar CUDA." "ERROR"
        }
    }
    
    # Actualizar PyTorch si se solicita
    if ($UpdatePyTorch) {
        $cudaMajorMinor = $CudaVersion.Substring(0, 4)  # Obtener "12.4" de "12.4.0"
        Log-Action "ACTUALIZANDO PYTORCH CON SOPORTE PARA CUDA $cudaMajorMinor" "INFO"
        $torchSuccess = Update-PyTorch -CudaVersion $cudaMajorMinor
        if ($torchSuccess) {
            Log-Action "PyTorch actualizado correctamente con soporte para CUDA $cudaMajorMinor." "SUCCESS"
        } else {
            Log-Action "Hubo problemas al actualizar PyTorch." "ERROR"
        }
    }
    
    # Actualizar Visual Studio si se solicita
    if ($UpdateVisualStudio) {
        Log-Action "ACTUALIZANDO VISUAL STUDIO" "INFO"
        $vsSuccess = Update-VisualStudio -UpdateOnly (-not $Force)
        if ($vsSuccess) {
            Log-Action "Visual Studio actualizado correctamente." "SUCCESS"
        } else {
            Log-Action "Hubo problemas al actualizar Visual Studio." "ERROR"
        }
    }
    
    # Actualizar paquetes Python si se solicita
    if ($UpdatePackages) {
        Log-Action "ACTUALIZANDO BIBLIOTECAS PYTHON" "INFO"
        $packagesSuccess = Update-PythonPackages
        if ($packagesSuccess) {
            Log-Action "Bibliotecas Python actualizadas correctamente." "SUCCESS"
        } else {
            Log-Action "Hubo problemas al actualizar bibliotecas Python." "ERROR"
        }
    }
    
    # Verificar componentes actualizados
    Log-Action "VERIFICANDO COMPONENTES DESPUÉS DE LA ACTUALIZACIÓN" "INFO"
    $updatedComponents = Detect-InstalledComponents
    
    # Mostrar resumen
    Log-Action "RESUMEN DE ACTUALIZACIÓN" "INFO"
    Log-Action "=============================" "INFO"
    foreach ($component in $updatedComponents.Keys) {
        Log-Action "$component: $($updatedComponents[$component].version)" "SUCCESS"
    }
    Log-Action "=============================" "INFO"
    
    # Sugerir reinicio
    Log-Action "Se recomienda reiniciar el sistema para completar la actualización." "WARNING"
    $restart = Confirm-Action "¿Deseas reiniciar el sistema ahora?"
    if ($restart) {
        Log-Action "Reiniciando el sistema..." "INFO"
        Start-Process "shutdown.exe" -ArgumentList "/r /t 10 /c `"Reinicio programado por script de actualización`""
    }
}

# Parámetros de línea de comandos
param (
    [switch]$Python,
    [switch]$CUDA,
    [switch]$PyTorch,
    [switch]$VisualStudio,
    [switch]$Packages,
    [switch]$All,
    [switch]$Force,
    [string]$PythonVersion = "3.10.11",
    [string]$CudaVersion = "12.4.0",
    [switch]$Help
)

# Mostrar ayuda
if ($Help) {
    Write-Host "`nScript de actualización de entorno de desarrollo para IA/ML`n" -ForegroundColor Cyan
    Write-Host "USO: .\update.ps1 [opciones]`n" -ForegroundColor Cyan
    Write-Host "Opciones:"
    Write-Host "  -Python           Actualizar Python a la versión especificada"
    Write-Host "  -CUDA             Actualizar CUDA a la versión especificada"
    Write-Host "  -PyTorch          Actualizar PyTorch con soporte para CUDA"
    Write-Host "  -VisualStudio     Actualizar Visual Studio"
    Write-Host "  -Packages         Actualizar bibliotecas Python"
    Write-Host "  -All              Actualizar todos los componentes"
    Write-Host "  -Force            Forzar reinstalación incluso si ya está actualizado"
    Write-Host "  -PythonVersion    Especificar versión de Python (por defecto: 3.10.11)"
    Write-Host "  -CudaVersion      Especificar versión de CUDA (por defecto: 12.4.0)"
    Write-Host "  -Help             Mostrar esta ayuda"
    Write-Host "`nEjemplos:"
    Write-Host "  .\update.ps1 -All                    Actualizar todos los componentes"
    Write-Host "  .\update.ps1 -Python -PythonVersion 3.11.5   Actualizar sólo Python a la versión 3.11.5"
    Write-Host "  .\update.ps1 -CUDA -PyTorch          Actualizar CUDA y PyTorch manteniendo Python"
    Write-Host ""
    exit 0
}

# Ejecutar proceso de actualización
Start-UpdateProcess -UpdatePython:$Python -UpdateCUDA:$CUDA -UpdatePyTorch:$PyTorch -UpdateVisualStudio:$VisualStudio -UpdatePackages:$Packages -All:$All -Force:$Force -PythonVersion $PythonVersion -CudaVersion $CudaVersion