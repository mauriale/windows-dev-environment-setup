# Script para limpiar completamente el entorno de desarrollo en Windows 11
# Desinstala Visual Studio, Python, CUDA, cuDNN y componentes relacionados

# Definir la ruta del archivo de log
$logFilePath = "cleanup_log.txt"

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

# Configuración de visualización y registro detallado
$VerboseMode = $true  # Mostrar detalles completos de cada operación
$ProgressPreference = 'Continue'  # Mostrar barras de progreso para operaciones largas

# Iniciar el archivo de log con encabezado
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logHeader = @"
===========================================================================
            LIMPIEZA DE ENTORNO DE DESARROLLO - LOG DE EJECUCIÓN
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
        [string]$Type = "INFO",
        [bool]$ShowDetails = $false
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path $logFilePath -Value $logMessage -Force
    
    switch ($Type) {
        "INFO" { 
            if ($VerboseMode -or $ShowDetails) {
                Write-Host $logMessage -ForegroundColor Gray 
            }
        }
        "DEBUG" { 
            if ($VerboseMode) {
                Write-Host $logMessage -ForegroundColor DarkGray 
            }
        }
        "COMMAND" { 
            if ($VerboseMode) {
                Write-Host $logMessage -ForegroundColor Cyan 
            }
        }
        "WAIT" { 
            Write-Host $logMessage -ForegroundColor Magenta
        }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Función para ejecutar comandos con registro detallado
function Execute-Command {
    param (
        [string]$Command,
        [string]$Description,
        [int]$TimeoutSeconds = 0,  # 0 significa sin timeout
        [bool]$CaptureOutput = $true
    )
    
    Log-Action "Ejecutando: $Command" "COMMAND"
    Log-Action $Description "DEBUG"
    
    try {
        if ($TimeoutSeconds -gt 0) {
            Log-Action "Timeout configurado: $TimeoutSeconds segundos" "DEBUG"
        }
        
        $startTime = Get-Date
        
        if ($CaptureOutput) {
            $output = Invoke-Expression -Command $Command -ErrorVariable errorMsg 2>&1
            
            if ($output) {
                foreach ($line in $output) {
                    Log-Action "  > $line" "DEBUG"
                }
            }
        } 
        else {
            Invoke-Expression -Command $Command -ErrorVariable errorMsg
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Log-Action "Comando ejecutado correctamente (duración: $([Math]::Round($duration, 2)) segundos)" "DEBUG"
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

# Función para mostrar progreso en operaciones largas
function Show-Progress {
    param (
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$SecondsRemaining = -1
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    
    if ($SecondsRemaining -gt 0) {
        Log-Action "Progreso: $Status ($PercentComplete% completado, $SecondsRemaining segundos restantes)" "DEBUG"
    } else {
        Log-Action "Progreso: $Status ($PercentComplete% completado)" "DEBUG"
    }
}

# Función para verificar rutas en el PATH y eliminar las que ya no existen
function Clean-PathEnvironment {
    param (
        [string]$Scope  # "User" o "Machine"
    )

    Log-Action "Verificando rutas en variables PATH de $Scope..." "INFO" $true
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", $Scope)
    
    if (-not $currentPath) {
        Log-Action "No hay variable PATH definida para $Scope" "INFO"
        return
    }
    
    Log-Action "PATH de $Scope actual: $currentPath" "DEBUG"
    
    $pathsArray = $currentPath -split ';' | Where-Object { $_ -ne "" }
    $validPaths = @()
    $invalidPaths = @()
    
    foreach ($path in $pathsArray) {
        if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
            $validPaths += $path
        } else {
            $invalidPaths += $path
        }
    }
    
    if ($invalidPaths.Count -gt 0) {
        Log-Action "Encontradas $($invalidPaths.Count) rutas que ya no existen en PATH de $Scope:" "INFO" $true
        foreach ($invalid in $invalidPaths) {
            Log-Action "  - $invalid" "INFO" $true
        }
        
        $newPath = $validPaths -join ';'
        
        try {
            Log-Action "Actualizando PATH de $Scope para eliminar rutas inválidas..." "COMMAND"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, $Scope)
            Log-Action "PATH de $Scope actualizado correctamente" "SUCCESS" $true
        }
        catch {
            Log-Action "Error al actualizar PATH de $Scope: $_" "ERROR" $true
        }
    }
    else {
        Log-Action "No se encontraron rutas inválidas en PATH de $Scope" "SUCCESS" $true
    }
}

# Función para esperar a que un proceso termine
function Wait-ForProcess {
    param (
        [string]$ProcessName,
        [int]$TimeoutSeconds = 300,  # 5 minutos por defecto
        [int]$CheckIntervalSeconds = 5
    )
    
    Log-Action "Esperando a que los procesos de '$ProcessName' terminen..." "WAIT" $true
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $endTime) {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        
        if ($processes.Count -eq 0) {
            Log-Action "No hay procesos de '$ProcessName' en ejecución" "SUCCESS" $true
            return $true
        }
        
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $remaining = $TimeoutSeconds - $elapsed
        $percent = [Math]::Min(100, [Math]::Round(($elapsed / $TimeoutSeconds) * 100))
        
        Show-Progress -Activity "Esperando procesos" -Status "Esperando que terminen procesos de $ProcessName" -PercentComplete $percent -SecondsRemaining ([Math]::Round($remaining))
        
        Log-Action "Encontrados $($processes.Count) procesos de '$ProcessName' en ejecución. Esperando $CheckIntervalSeconds segundos..." "WAIT"
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
    
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($processes.Count -gt 0) {
        Log-Action "Tiempo de espera agotado. Aún hay $($processes.Count) procesos de '$ProcessName' en ejecución." "WARNING" $true
        foreach ($process in $processes) {
            Log-Action "  - PID: $($process.Id), Nombre: $($process.ProcessName), Título: $($process.MainWindowTitle)" "WARNING"
        }
        
        $forceKill = Read-Host "¿Deseas forzar el cierre de estos procesos? (S/N)"
        if ($forceKill -eq "S") {
            Log-Action "Forzando cierre de procesos de '$ProcessName'..." "WARNING" $true
            try {
                Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
                Log-Action "Procesos de '$ProcessName' terminados forzosamente" "SUCCESS" $true
                return $true
            }
            catch {
                Log-Action "Error al forzar el cierre de procesos: $_" "ERROR" $true
                return $false
            }
        }
        return $false
    }
    
    return $true
}

# Función para verificar y limpiar entradas de registro huérfanas
function Check-RegistryOrphanedEntries {
    param (
        [string]$RegistryPath,
        [string]$SearchPattern,
        [string]$Description
    )
    
    Log-Action "Verificando entradas de registro huérfanas para $Description en $RegistryPath..." "INFO" $true
    
    if (-not (Test-Path $RegistryPath -ErrorAction SilentlyContinue)) {
        Log-Action "La ruta de registro $RegistryPath no existe" "DEBUG"
        return
    }
    
    try {
        $regEntries = Get-ChildItem -Path $RegistryPath -Recurse -ErrorAction SilentlyContinue | 
                      Where-Object { $_.Name -like "*$SearchPattern*" -or $_.Property -like "*$SearchPattern*" }
        
        if ($regEntries -and $regEntries.Count -gt 0) {
            Log-Action "Encontradas $($regEntries.Count) entradas de registro relacionadas con $Description" "INFO" $true
            
            $i = 0
            foreach ($entry in $regEntries) {
                $i++
                Log-Action "Eliminando entrada de registro: $($entry.Name)" "INFO"
                
                try {
                    Remove-Item -Path $entry.PSPath -Recurse -Force -ErrorAction Stop
                    Log-Action "Entrada de registro eliminada correctamente" "SUCCESS"
                }
                catch {
                    Log-Action "Error al eliminar entrada de registro: $_" "ERROR"
                }
                
                $percent = [Math]::Round(($i / $regEntries.Count) * 100)
                Show-Progress -Activity "Limpieza de registro" -Status "Limpiando entradas de $Description" -PercentComplete $percent
            }
            
            Log-Action "Limpieza de entradas de registro para $Description completada" "SUCCESS" $true
        }
        else {
            Log-Action "No se encontraron entradas de registro huérfanas para $Description" "SUCCESS" $true
        }
    }
    catch {
        Log-Action "Error al verificar entradas de registro para $Description: $_" "ERROR" $true
    }
}

# Mostrar banner de inicio
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "            LIMPIEZA DE ENTORNO DE DESARROLLO" -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

# Mostrar advertencia y pedir confirmación
Log-Action "¡ADVERTENCIA! Este script desinstalará completamente Visual Studio, Python, CUDA y componentes relacionados." "WARNING" $true
Log-Action "Asegúrate de haber hecho una copia de seguridad de tus proyectos y datos importantes." "WARNING" $true
$confirmation = Read-Host "¿Deseas continuar? (S/N)"
if ($confirmation -ne "S") {
    Log-Action "Operación cancelada por el usuario." "WARNING" $true
    exit 0
}

Log-Action "Iniciando proceso de limpieza del sistema..." "INFO" $true

# 1. Preparación: Verificar y cerrar procesos en ejecución
Log-Action "PASO 0: Preparación - Verificando procesos en ejecución" "INFO" $true

$processesToCheck = @(
    @{ Name = "devenv"; Description = "Visual Studio" },
    @{ Name = "VSIXInstaller"; Description = "Visual Studio VSIX Installer" },
    @{ Name = "vs_installer"; Description = "Visual Studio Installer" },
    @{ Name = "vs_bootstrapper"; Description = "Visual Studio Bootstrapper" },
    @{ Name = "MSBuild"; Description = "Microsoft Build Engine" },
    @{ Name = "python"; Description = "Python" },
    @{ Name = "pip"; Description = "Python Package Installer" },
    @{ Name = "nvcc"; Description = "NVIDIA CUDA Compiler" },
    @{ Name = "nvidia-smi"; Description = "NVIDIA System Management Interface" }
)

$processesRunning = $false

foreach ($proc in $processesToCheck) {
    Log-Action "Verificando procesos de $($proc.Description) ($($proc.Name))..." "INFO" $true
    
    $processes = Get-Process -Name $proc.Name -ErrorAction SilentlyContinue
    if ($processes.Count -gt 0) {
        $processesRunning = $true
        Log-Action "Procesos de $($proc.Description) en ejecución: $($processes.Count)" "WARNING" $true
        foreach ($process in $processes | Select-Object -First 5) {
            Log-Action "  - PID: $($process.Id), Nombre: $($process.ProcessName), Título: $($process.MainWindowTitle)" "WARNING"
        }
        
        if ($processes.Count -gt 5) {
            Log-Action "  ... y $($processes.Count - 5) procesos más" "WARNING"
        }
        
        $waitForClose = Read-Host "¿Deseas esperar a que estos procesos terminen? (S/N)"
        if ($waitForClose -eq "S") {
            Log-Action "Esperando a que los procesos de $($proc.Description) terminen..." "INFO" $true
            Wait-ForProcess -ProcessName $proc.Name -TimeoutSeconds 180 -CheckIntervalSeconds 5
        }
        else {
            $forceClose = Read-Host "¿Deseas forzar el cierre de estos procesos? (S/N)"
            if ($forceClose -eq "S") {
                Log-Action "Forzando cierre de procesos de $($proc.Description)..." "WARNING" $true
                try {
                    Stop-Process -Name $proc.Name -Force -ErrorAction SilentlyContinue
                    Log-Action "Procesos de $($proc.Description) terminados forzosamente" "SUCCESS" $true
                    Start-Sleep -Seconds 2  # Esperar un momento para que los procesos terminen
                }
                catch {
                    Log-Action "Error al forzar el cierre de procesos: $_" "ERROR" $true
                }
            }
        }
    }
    else {
        Log-Action "No se encontraron procesos de $($proc.Description) en ejecución" "SUCCESS" $true
    }
}

# 2. Desinstalar versiones de Visual Studio
Log-Action "PASO 1: Desinstalando Visual Studio y componentes relacionados" "INFO" $true
Log-Action "Buscando instalaciones de Visual Studio..." "INFO" $true

# Buscar instalaciones de Visual Studio
$vsInstalls = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Visual Studio*" }
if ($vsInstalls) {
    Log-Action "Se encontraron $(($vsInstalls | Measure-Object).Count) instalaciones de Visual Studio:" "INFO" $true
    
    # Mostrar todas las instalaciones encontradas
    foreach ($vs in $vsInstalls) {
        Log-Action "  - $($vs.Name) (Versión: $($vs.Version), ID: $($vs.IdentifyingNumber))" "INFO" $true
    }
    
    $i = 0
    foreach ($vs in $vsInstalls) {
        $i++
        Log-Action "[$i/$(($vsInstalls | Measure-Object).Count)] Desinstalando $($vs.Name)..." "INFO" $true
        Log-Action "ID: $($vs.IdentifyingNumber)" "DEBUG"
        Log-Action "Versión: $($vs.Version)" "DEBUG"
        Log-Action "Ruta: $($vs.InstallLocation)" "DEBUG"
        
        Show-Progress -Activity "Desinstalando Visual Studio" -Status "Desinstalando $($vs.Name)" -PercentComplete ([math]::Round(($i / ($vsInstalls | Measure-Object).Count) * 100))
        
        try {
            Log-Action "Iniciando desinstalación de $($vs.Name)" "COMMAND"
            $vs.Uninstall() | Out-Null
            
            # Esperar a que el proceso msiexec termine
            Log-Action "Esperando a que el desinstalador termine..." "WAIT" $true
            Wait-ForProcess -ProcessName "msiexec" -TimeoutSeconds 300 -CheckIntervalSeconds 10
            
            Log-Action "Visual Studio $($vs.Name) desinstalado correctamente." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al desinstalar $($vs.Name): $_" "ERROR" $true
        }
    }
} else {
    Log-Action "No se encontraron instalaciones de Visual Studio por WMI." "INFO" $true
}

# Desinstalar Visual Studio usando el instalador oficial (más confiable)
Log-Action "Buscando Visual Studio Installer para una desinstalación más limpia..." "INFO" $true
$vsInstallerPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vs_installer.exe"
)

$vsInstallerFound = $false
foreach ($vsInstallerPath in $vsInstallerPaths) {
    if (Test-Path $vsInstallerPath) {
        $vsInstallerFound = $true
        Log-Action "Visual Studio Installer encontrado en: $vsInstallerPath" "INFO" $true
        Log-Action "Desinstalando Visual Studio usando el instalador oficial..." "INFO" $true
        
        try {
            # Primero, ejecutar vs_installer para asegurar que se actualiza el instalador
            Log-Action "Actualizando Visual Studio Installer..." "INFO" $true
            $command = "Start-Process -FilePath '$vsInstallerPath' -ArgumentList 'update --quiet' -Wait -PassThru"
            Execute-Command -Command $command -Description "Actualización del Visual Studio Installer"
            
            # Ahora desinstalar todas las instancias
            Log-Action "Desinstalando todas las instancias de Visual Studio (esto puede tardar varios minutos)..." "INFO" $true
            $command = "Start-Process -FilePath '$vsInstallerPath' -ArgumentList 'uninstall --all --force' -Wait -PassThru"
            $result = Execute-Command -Command $command -Description "Desinstalación de todas las instancias de Visual Studio"
            
            # Esperar a que los procesos relacionados terminen
            Log-Action "Esperando a que el instalador de Visual Studio termine..." "WAIT" $true
            Wait-ForProcess -ProcessName "vs_installer" -TimeoutSeconds 600 -CheckIntervalSeconds 15
            
            if ($result) {
                Log-Action "Proceso de desinstalación de Visual Studio completado." "SUCCESS" $true
            } else {
                Log-Action "El proceso de desinstalación de Visual Studio puede haber tenido problemas." "WARNING" $true
            }
        }
        catch {
            Log-Action "Error al ejecutar el desinstalador de Visual Studio: $_" "ERROR" $true
        }
    }
}

if (-not $vsInstallerFound) {
    Log-Action "No se encontró el instalador de Visual Studio. Continuando con otros métodos de limpieza." "WARNING" $true
}

# 3. Desinstalar Build Tools y otros componentes de Visual Studio
Log-Action "PASO 2: Desinstalando Build Tools y componentes de desarrollo" "INFO" $true
Log-Action "Buscando Build Tools y componentes de Visual Studio..." "INFO" $true

$buildToolPatterns = @(
    "*Build Tools*",
    "*Microsoft Visual C++*",
    "*Microsoft .NET*",
    "*Windows SDK*"
)

$allBuildTools = @()

foreach ($pattern in $buildToolPatterns) {
    $components = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
    if ($components) {
        $allBuildTools += $components
        Log-Action "Encontrados $(($components | Measure-Object).Count) componentes que coinciden con '$pattern'" "INFO" $true
    }
}

if ($allBuildTools.Count -gt 0) {
    Log-Action "Se encontraron $($allBuildTools.Count) componentes de Build Tools en total:" "INFO" $true
    
    # Mostrar todos los componentes encontrados
    foreach ($bt in $allBuildTools) {
        Log-Action "  - $($bt.Name) (Versión: $($bt.Version))" "INFO" $true
    }
    
    $i = 0
    foreach ($bt in $allBuildTools) {
        $i++
        Log-Action "[$i/$($allBuildTools.Count)] Desinstalando $($bt.Name)..." "INFO" $true
        Log-Action "ID: $($bt.IdentifyingNumber)" "DEBUG"
        Log-Action "Versión: $($bt.Version)" "DEBUG"
        Log-Action "Ruta: $($bt.InstallLocation)" "DEBUG"
        
        Show-Progress -Activity "Desinstalando Build Tools" -Status "Desinstalando $($bt.Name)" -PercentComplete ([math]::Round(($i / $allBuildTools.Count) * 100))
        
        try {
            Log-Action "Iniciando desinstalación de $($bt.Name)" "COMMAND"
            $bt.Uninstall() | Out-Null
            
            # Esperar a que los procesos relacionados terminen
            Log-Action "Esperando a que el desinstalador termine..." "WAIT" $true
            Wait-ForProcess -ProcessName "msiexec" -TimeoutSeconds 300 -CheckIntervalSeconds 10
            
            Log-Action "$($bt.Name) desinstalado correctamente." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al desinstalar $($bt.Name): $_" "ERROR" $true
        }
    }
} else {
    Log-Action "No se encontraron Build Tools por WMI." "INFO" $true
}