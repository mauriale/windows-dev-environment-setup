# Script para hacer copias de seguridad antes de ejecutar la limpieza
# Respalda archivos y configuraciones importantes

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

# Definir la ruta del archivo de log
$logFilePath = "backup_log.txt"

# Iniciar el archivo de log con encabezado
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logHeader = @"
===========================================================================
            BACKUP DE ENTORNO DE DESARROLLO - LOG DE EJECUCIÓN
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

# Función para comprobar espacio en disco
function Check-DiskSpace {
    param (
        [string]$Path,
        [long]$RequiredSpaceGB
    )
    
    $drive = Split-Path -Qualifier $Path
    $freeSpace = (Get-PSDrive $drive.TrimEnd(":")).Free
    $requiredSpace = $RequiredSpaceGB * 1GB
    
    Log-Action "Espacio libre en unidad $drive`: $([Math]::Round($freeSpace / 1GB, 2)) GB" "INFO"
    
    if ($freeSpace -lt $requiredSpace) {
        Log-Action "Espacio insuficiente en unidad $drive. Se requieren al menos $RequiredSpaceGB GB para la copia de seguridad." "ERROR"
        return $false
    }
    
    return $true
}

# Función para crear directorio de backup con fecha y hora
function Create-BackupDirectory {
    param (
        [string]$BasePath = "$env:USERPROFILE\Backups"
    )
    
    $dateStr = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupPath = Join-Path -Path $BasePath -ChildPath "DevEnvBackup_$dateStr"
    
    if (-not (Test-Path $BasePath)) {
        try {
            New-Item -Path $BasePath -ItemType Directory -Force | Out-Null
            Log-Action "Directorio base de copias de seguridad creado: $BasePath" "SUCCESS"
        }
        catch {
            Log-Action "Error al crear directorio base de copias de seguridad: $_" "ERROR"
            return $null
        }
    }
    
    try {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        Log-Action "Directorio de copia de seguridad creado: $backupPath" "SUCCESS"
        return $backupPath
    }
    catch {
        Log-Action "Error al crear directorio de copia de seguridad: $_" "ERROR"
        return $null
    }
}

# Función para respaldar archivos de proyecto
function Backup-ProjectFiles {
    param (
        [string]$BackupPath,
        [array]$ProjectPaths
    )
    
    $projectBackupPath = Join-Path -Path $BackupPath -ChildPath "Projects"
    New-Item -Path $projectBackupPath -ItemType Directory -Force | Out-Null
    
    Log-Action "Iniciando copia de seguridad de proyectos..." "INFO"
    
    $totalProjects = $ProjectPaths.Count
    $projectsBackedUp = 0
    
    foreach ($projectPath in $ProjectPaths) {
        if (Test-Path $projectPath) {
            $projectName = Split-Path -Leaf $projectPath
            $destPath = Join-Path -Path $projectBackupPath -ChildPath $projectName
            
            Log-Action "Copiando proyecto: $projectName" "INFO"
            
            try {
                # Excluir node_modules, __pycache__, venv y otros directorios grandes
                $excludeDirs = @("node_modules", "__pycache__", "venv", ".venv", "env", ".env", "build", "dist", ".git")
                $excludePatterns = $excludeDirs | ForEach-Object { "\\$_\\" }
                
                if (Test-Path $projectPath -PathType Container) {
                    # Es un directorio, copiar con robocopy para mejor rendimiento
                    $excludeArgs = $excludeDirs | ForEach-Object { "/XD `"$_`"" }
                    $robocopyArgs = @($projectPath, $destPath, "/E", "/NP", "/NFL", "/NDL", "/NS", "/NC", "/MT:8") + $excludeArgs
                    
                    # Ejecutar robocopy (códigos de salida 0-7 son éxito en robocopy)
                    $process = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
                    if ($process.ExitCode -le 7) {
                        Log-Action "Proyecto $projectName respaldado correctamente" "SUCCESS"
                        $projectsBackedUp++
                    }
                    else {
                        Log-Action "Error al respaldar proyecto $projectName. Código de salida: $($process.ExitCode)" "ERROR"
                    }
                }
                else {
                    # Es un archivo individual
                    Copy-Item -Path $projectPath -Destination $projectBackupPath -Force
                    Log-Action "Archivo $projectName respaldado correctamente" "SUCCESS"
                    $projectsBackedUp++
                }
            }
            catch {
                Log-Action "Error al respaldar proyecto $projectName`: $_" "ERROR"
            }
        }
        else {
            Log-Action "Proyecto no encontrado: $projectPath" "WARNING"
        }
    }
    
    Log-Action "Copia de seguridad de proyectos completada: $projectsBackedUp de $totalProjects proyectos respaldados" "INFO"
    return $projectsBackedUp
}

# Función para respaldar configuraciones de Python
function Backup-PythonConfiguration {
    param (
        [string]$BackupPath
    )
    
    $configBackupPath = Join-Path -Path $BackupPath -ChildPath "PythonConfig"
    New-Item -Path $configBackupPath -ItemType Directory -Force | Out-Null
    
    Log-Action "Respaldando configuraciones de Python..." "INFO"
    
    # Buscar instalaciones de Python
    $pythonPaths = @(
        "${env:ProgramFiles}\Python*",
        "${env:ProgramFiles(x86)}\Python*",
        "${env:LocalAppData}\Programs\Python\Python*"
    )
    
    $configsBackedUp = 0
    
    # Respaldar lista de paquetes instalados por cada versión de Python
    foreach ($pythonPathPattern in $pythonPaths) {
        $pythonDirs = Get-Item -Path $pythonPathPattern -ErrorAction SilentlyContinue
        
        foreach ($pythonDir in $pythonDirs) {
            $pythonVersion = $pythonDir.Name -replace 'Python', ''
            $pipPath = Join-Path -Path $pythonDir.FullName -ChildPath "Scripts\pip.exe"
            
            if (Test-Path $pipPath) {
                $outputFile = Join-Path -Path $configBackupPath -ChildPath "pip_packages_$pythonVersion.txt"
                
                try {
                    $process = Start-Process -FilePath $pipPath -ArgumentList "freeze" -NoNewWindow -Wait -RedirectStandardOutput $outputFile -PassThru
                    
                    if ($process.ExitCode -eq 0) {
                        Log-Action "Lista de paquetes Python $pythonVersion guardada en: $outputFile" "SUCCESS"
                        $configsBackedUp++
                    }
                    else {
                        Log-Action "Error al listar paquetes de Python $pythonVersion" "ERROR"
                    }
                }
                catch {
                    Log-Action "Error al ejecutar pip freeze para Python $pythonVersion`: $_" "ERROR"
                }
            }
        }
    }
    
    # Respaldar archivos de configuración pip
    $pipConfigPaths = @(
        "$env:APPDATA\pip\pip.ini",
        "$env:HOME\.pip\pip.conf"
    )
    
    foreach ($pipConfig in $pipConfigPaths) {
        if (Test-Path $pipConfig) {
            $destFile = Join-Path -Path $configBackupPath -ChildPath (Split-Path -Leaf $pipConfig)
            
            try {
                Copy-Item -Path $pipConfig -Destination $destFile -Force
                Log-Action "Configuración de pip respaldada: $pipConfig" "SUCCESS"
                $configsBackedUp++
            }
            catch {
                Log-Action "Error al respaldar configuración de pip $pipConfig`: $_" "ERROR"
            }
        }
    }
    
    # Respaldar variables de entorno relacionadas con Python
    $envFile = Join-Path -Path $configBackupPath -ChildPath "python_environment_variables.txt"
    $envVars = Get-ChildItem env: | Where-Object { 
        $_.Name -like "PYTHON*" -or 
        $_.Name -eq "PATH" -or 
        $_.Name -like "PIP_*"
    }
    
    $envVarsContent = $envVars | ForEach-Object { "$($_.Name)=$($_.Value)" }
    Set-Content -Path $envFile -Value $envVarsContent -Force
    
    Log-Action "Variables de entorno de Python respaldadas en: $envFile" "SUCCESS"
    $configsBackedUp++
    
    Log-Action "Copia de seguridad de configuraciones de Python completada: $configsBackedUp elementos respaldados" "INFO"
    return $configsBackedUp
}

# Función para respaldar configuraciones de Visual Studio
function Backup-VisualStudioConfiguration {
    param (
        [string]$BackupPath
    )
    
    $vsBackupPath = Join-Path -Path $BackupPath -ChildPath "VisualStudioConfig"
    New-Item -Path $vsBackupPath -ItemType Directory -Force | Out-Null
    
    Log-Action "Respaldando configuraciones de Visual Studio..." "INFO"
    
    $configsBackedUp = 0
    
    # Respaldar configuraciones de usuario
    $vsConfigPaths = @(
        "$env:LOCALAPPDATA\Microsoft\VisualStudio",
        "$env:APPDATA\Microsoft\VisualStudio"
    )
    
    foreach ($vsConfigPath in $vsConfigPaths) {
        if (Test-Path $vsConfigPath) {
            $settingsFiles = Get-ChildItem -Path $vsConfigPath -Recurse -File -Include "*.vssettings", "*.vsconfig", "*.json" -ErrorAction SilentlyContinue
            
            foreach ($settingsFile in $settingsFiles) {
                # Crear estructura de directorios relativa
                $relativePath = $settingsFile.FullName.Substring($vsConfigPath.Length + 1)
                $destFile = Join-Path -Path $vsBackupPath -ChildPath $relativePath
                $destDir = Split-Path -Path $destFile -Parent
                
                if (-not (Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }
                
                try {
                    Copy-Item -Path $settingsFile.FullName -Destination $destFile -Force
                    Log-Action "Configuración VS respaldada: $relativePath" "SUCCESS"
                    $configsBackedUp++
                }
                catch {
                    Log-Action "Error al respaldar configuración VS $($settingsFile.FullName)`: $_" "ERROR"
                }
            }
        }
    }
    
    # Respaldar extensiones instaladas
    $vsixInstallerPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\VSIXInstaller.exe"
    if (Test-Path $vsixInstallerPath) {
        $extensionsFile = Join-Path -Path $vsBackupPath -ChildPath "installed_extensions.txt"
        
        try {
            # Intentar listar extensiones instaladas (no hay un comando directo, usamos un enfoque alternativo)
            $extensionsDirs = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio" -Recurse -Directory -Filter "Extensions" -ErrorAction SilentlyContinue
            
            $extensions = @()
            foreach ($extensionsDir in $extensionsDirs) {
                $manifestFiles = Get-ChildItem -Path $extensionsDir.FullName -Recurse -File -Filter "extension.vsixmanifest" -ErrorAction SilentlyContinue
                
                foreach ($manifestFile in $manifestFiles) {
                    try {
                        $content = Get-Content -Path $manifestFile.FullName -Raw
                        if ($content -match 'Identity.*?Id="([^"]+)".*?Version="([^"]+)"') {
                            $extensions += "$($Matches[1]) (v$($Matches[2]))"
                        }
                    }
                    catch {
                        # Ignorar errores en la lectura de manifiestos
                    }
                }
            }
            
            Set-Content -Path $extensionsFile -Value $extensions -Force
            Log-Action "Lista de extensiones VS guardada en: $extensionsFile" "SUCCESS"
            $configsBackedUp++
        }
        catch {
            Log-Action "Error al listar extensiones de Visual Studio: $_" "ERROR"
        }
    }
    
    Log-Action "Copia de seguridad de configuraciones de Visual Studio completada: $configsBackedUp elementos respaldados" "INFO"
    return $configsBackedUp
}

# Función para respaldar configuraciones de CUDA
function Backup-CudaConfiguration {
    param (
        [string]$BackupPath
    )
    
    $cudaBackupPath = Join-Path -Path $BackupPath -ChildPath "CudaConfig"
    New-Item -Path $cudaBackupPath -ItemType Directory -Force | Out-Null
    
    Log-Action "Respaldando configuraciones de CUDA..." "INFO"
    
    $configsBackedUp = 0
    
    # Respaldar información del driver NVIDIA
    $driverInfoFile = Join-Path -Path $cudaBackupPath -ChildPath "nvidia_driver_info.txt"
    
    try {
        $nvidiaSmiOutput = & nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            Set-Content -Path $driverInfoFile -Value $nvidiaSmiOutput -Force
            Log-Action "Información del driver NVIDIA guardada en: $driverInfoFile" "SUCCESS"
            $configsBackedUp++
        }
        else {
            Log-Action "No se pudo obtener información del driver NVIDIA" "WARNING"
        }
    }
    catch {
        Log-Action "Error al ejecutar nvidia-smi: $_" "ERROR"
    }
    
    # Respaldar información de NVCC
    $nvccInfoFile = Join-Path -Path $cudaBackupPath -ChildPath "nvcc_info.txt"
    
    try {
        $nvccOutput = & nvcc --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Set-Content -Path $nvccInfoFile -Value $nvccOutput -Force
            Log-Action "Información de NVCC guardada en: $nvccInfoFile" "SUCCESS"
            $configsBackedUp++
        }
        else {
            Log-Action "No se pudo obtener información de NVCC" "WARNING"
        }
    }
    catch {
        Log-Action "Error al ejecutar nvcc: $_" "ERROR"
    }
    
    # Respaldar variables de entorno relacionadas con CUDA
    $envFile = Join-Path -Path $cudaBackupPath -ChildPath "cuda_environment_variables.txt"
    $envVars = Get-ChildItem env: | Where-Object { 
        $_.Name -like "CUDA*" -or 
        $_.Name -like "NVCC*" -or 
        $_.Name -like "CUDNN*" -or
        $_.Name -eq "PATH"
    }
    
    $envVarsContent = $envVars | ForEach-Object { "$($_.Name)=$($_.Value)" }
    Set-Content -Path $envFile -Value $envVarsContent -Force
    
    Log-Action "Variables de entorno de CUDA respaldadas en: $envFile" "SUCCESS"
    $configsBackedUp++
    
    Log-Action "Copia de seguridad de configuraciones de CUDA completada: $configsBackedUp elementos respaldados" "INFO"
    return $configsBackedUp
}

# Función para comprimir la copia de seguridad
function Compress-BackupDirectory {
    param (
        [string]$BackupPath
    )
    
    Log-Action "Comprimiendo directorio de copia de seguridad..." "INFO"
    
    $zipFile = "$BackupPath.zip"
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($BackupPath, $zipFile)
        
        Log-Action "Directorio comprimido correctamente: $zipFile" "SUCCESS"
        
        # Calcular tamaño del archivo ZIP
        $zipSize = (Get-Item $zipFile).Length
        $zipSizeMB = [Math]::Round($zipSize / 1MB, 2)
        
        Log-Action "Tamaño del archivo ZIP: $zipSizeMB MB" "INFO"
        
        return $zipFile
    }
    catch {
        Log-Action "Error al comprimir directorio: $_" "ERROR"
        return $null
    }
}

# Mostrar banner de inicio
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "            COPIA DE SEGURIDAD DEL ENTORNO DE DESARROLLO" -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

Log-Action "Iniciando proceso de copia de seguridad..." "INFO"

# Solicitar directorio de destino para la copia de seguridad
$defaultBackupDir = "$env:USERPROFILE\Backups"
$customBackupDir = Read-Host "Ingresa el directorio donde deseas guardar la copia de seguridad [$defaultBackupDir]"

if ([string]::IsNullOrWhiteSpace($customBackupDir)) {
    $backupBaseDir = $defaultBackupDir
}
else {
    $backupBaseDir = $customBackupDir
}

Log-Action "Directorio base para copias de seguridad: $backupBaseDir" "INFO"

# Verificar espacio en disco
$requiredSpaceGB = 5  # Estimar al menos 5 GB para la copia de seguridad
if (-not (Check-DiskSpace -Path $backupBaseDir -RequiredSpaceGB $requiredSpaceGB)) {
    $continueAnyway = Confirm-Action "Espacio insuficiente. ¿Deseas continuar de todos modos?"
    if (-not $continueAnyway) {
        Log-Action "Operación cancelada por el usuario debido a espacio insuficiente." "WARNING"
        exit 0
    }
}

# Crear directorio de backup
$backupPath = Create-BackupDirectory -BasePath $backupBaseDir
if (-not $backupPath) {
    Log-Action "No se pudo crear el directorio de copia de seguridad. Abortando." "ERROR"
    exit 1
}

# Solicitar directorios de proyectos a respaldar
Log-Action "A continuación, ingresa las rutas de tus proyectos o archivos importantes a respaldar." "INFO"
Log-Action "Puedes ingresar varias rutas separadas por punto y coma (;)" "INFO"
Log-Action "Ejemplos: C:\Proyectos\MiProyecto; D:\Documentos\codigo.py" "INFO"

$defaultProjectsDir = "$env:USERPROFILE\Documents"
$projectsInput = Read-Host "Ingresa las rutas de tus proyectos [$defaultProjectsDir]"

if ([string]::IsNullOrWhiteSpace($projectsInput)) {
    $projectPaths = @($defaultProjectsDir)
}
else {
    $projectPaths = $projectsInput -split ";" | ForEach-Object { $_.Trim() }
}

# Respaldar archivos de proyectos
$projectsBackedUp = Backup-ProjectFiles -BackupPath $backupPath -ProjectPaths $projectPaths

# Preguntar si desea respaldar configuraciones de Python
$backupPython = Confirm-Action "¿Deseas respaldar configuraciones de Python (paquetes instalados, configuraciones pip)?"
if ($backupPython) {
    $pythonConfigsBackedUp = Backup-PythonConfiguration -BackupPath $backupPath
}

# Preguntar si desea respaldar configuraciones de Visual Studio
$backupVS = Confirm-Action "¿Deseas respaldar configuraciones de Visual Studio?"
if ($backupVS) {
    $vsConfigsBackedUp = Backup-VisualStudioConfiguration -BackupPath $backupPath
}

# Preguntar si desea respaldar configuraciones de CUDA
$backupCuda = Confirm-Action "¿Deseas respaldar configuraciones de CUDA?"
if ($backupCuda) {
    $cudaConfigsBackedUp = Backup-CudaConfiguration -BackupPath $backupPath
}

# Comprimir el directorio de backup
$zipFile = Compress-BackupDirectory -BackupPath $backupPath

# Resumen de la copia de seguridad
Log-Action "RESUMEN DE LA COPIA DE SEGURIDAD" "INFO"
Log-Action "==================================" "INFO"
Log-Action "Directorio de copia de seguridad: $backupPath" "INFO"
if ($zipFile) {
    Log-Action "Archivo comprimido: $zipFile" "INFO"
}
Log-Action "Proyectos respaldados: $projectsBackedUp" "INFO"
if ($backupPython) {
    Log-Action "Configuraciones de Python respaldadas: $pythonConfigsBackedUp" "INFO"
}
if ($backupVS) {
    Log-Action "Configuraciones de Visual Studio respaldadas: $vsConfigsBackedUp" "INFO"
}
if ($backupCuda) {
    Log-Action "Configuraciones de CUDA respaldadas: $cudaConfigsBackedUp" "INFO"
}
Log-Action "==================================" "INFO"

# Preguntar si desea eliminar el directorio original después de comprimir
if ($zipFile) {
    $deleteOriginal = Confirm-Action "¿Deseas eliminar el directorio original y mantener solo el archivo ZIP?"
    if ($deleteOriginal) {
        try {
            Remove-Item -Path $backupPath -Recurse -Force
            Log-Action "Directorio original eliminado: $backupPath" "SUCCESS"
        }
        catch {
            Log-Action "Error al eliminar directorio original: $_" "ERROR"
        }
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "                    COPIA DE SEGURIDAD COMPLETADA" -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan
Write-Host "Proceso completado a las $(Get-Date -Format "HH:mm:ss")" -ForegroundColor Green
Write-Host "`nArchivo de log generado: $logFilePath`n" -ForegroundColor Green

Log-Action "Copia de seguridad completada exitosamente." "SUCCESS"
