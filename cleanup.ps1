# Script para limpiar completamente el entorno de desarrollo en Windows 11
# Desinstala Visual Studio, Python, CUDA, cuDNN y componentes relacionados

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

Write-Host "¡ADVERTENCIA! Este script desinstalará completamente Visual Studio, Python, CUDA y componentes relacionados." -ForegroundColor Red
Write-Host "Asegúrate de haber hecho una copia de seguridad de tus proyectos y datos importantes." -ForegroundColor Red
$confirmation = Read-Host "¿Deseas continuar? (S/N)"
if ($confirmation -ne "S") {
    Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
    exit 0
}

# Función para registrar acciones en un archivo de log
function Log-Action {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path "cleanup_log.txt" -Value $logMessage -Force
    
    switch ($Type) {
        "INFO" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

Log-Action "Iniciando proceso de limpieza del sistema..." "INFO"

# 1. Desinstalar versiones de Visual Studio
Log-Action "Buscando instalaciones de Visual Studio..." "INFO"

# Buscar instalaciones de Visual Studio
$vsInstalls = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Visual Studio*" }
if ($vsInstalls) {
    foreach ($vs in $vsInstalls) {
        Log-Action "Desinstalando $($vs.Name)..." "INFO"
        try {
            $vs.Uninstall() | Out-Null
            Log-Action "Visual Studio $($vs.Name) desinstalado correctamente." "SUCCESS"
        }
        catch {
            Log-Action "Error al desinstalar $($vs.Name): $_" "ERROR"
        }
    }
} else {
    Log-Action "No se encontraron instalaciones de Visual Studio por WMI." "INFO"
}

# Desinstalar Visual Studio usando el instalador oficial (más confiable)
$vsInstallerPaths = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vs_installer.exe"
)

foreach ($vsInstallerPath in $vsInstallerPaths) {
    if (Test-Path $vsInstallerPath) {
        Log-Action "Desinstalando Visual Studio usando el instalador oficial..." "INFO"
        try {
            Start-Process -FilePath $vsInstallerPath -ArgumentList "uninstall --all --force" -Wait
            Log-Action "Proceso de desinstalación de Visual Studio completado." "SUCCESS"
        }
        catch {
            Log-Action "Error al ejecutar el desinstalador de Visual Studio: $_" "ERROR"
        }
    }
}

# 2. Desinstalar Build Tools y otros componentes de Visual Studio
Log-Action "Buscando Build Tools y componentes de Visual Studio..." "INFO"

$buildTools = Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.Name -like "*Build Tools*" -or 
    $_.Name -like "*Microsoft Visual C++*" -or
    $_.Name -like "*Microsoft .NET*" -or
    $_.Name -like "*Windows SDK*"
}

if ($buildTools) {
    foreach ($bt in $buildTools) {
        Log-Action "Desinstalando $($bt.Name)..." "INFO"
        try {
            $bt.Uninstall() | Out-Null
            Log-Action "$($bt.Name) desinstalado correctamente." "SUCCESS"
        }
        catch {
            Log-Action "Error al desinstalar $($bt.Name): $_" "ERROR"
        }
    }
} else {
    Log-Action "No se encontraron Build Tools por WMI." "INFO"
}

# 3. Desinstalar versiones de Python
Log-Action "Buscando instalaciones de Python..." "INFO"

# Buscar instalaciones de Python usando WMI
$pythonInstalls = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Python*" }
if ($pythonInstalls) {
    foreach ($python in $pythonInstalls) {
        Log-Action "Desinstalando $($python.Name)..." "INFO"
        try {
            $python.Uninstall() | Out-Null
            Log-Action "$($python.Name) desinstalado correctamente." "SUCCESS"
        }
        catch {
            Log-Action "Error al desinstalar $($python.Name): $_" "ERROR"
        }
    }
} else {
    Log-Action "No se encontraron instalaciones de Python por WMI." "INFO"
}

# Buscar instalaciones de Python por rutas comunes
$pythonPaths = @(
    "${env:ProgramFiles}\Python*",
    "${env:ProgramFiles(x86)}\Python*",
    "${env:LocalAppData}\Programs\Python\Python*"
)

foreach ($path in $pythonPaths) {
    $pythonDirs = Get-Item -Path $path -ErrorAction SilentlyContinue
    foreach ($dir in $pythonDirs) {
        $uninstallPath = Join-Path -Path $dir.FullName -ChildPath "uninstall.exe"
        if (Test-Path $uninstallPath) {
            Log-Action "Desinstalando Python desde $($dir.FullName)..." "INFO"
            try {
                Start-Process -FilePath $uninstallPath -ArgumentList "/quiet" -Wait
                Log-Action "Python desde $($dir.FullName) desinstalado correctamente." "SUCCESS"
            }
            catch {
                Log-Action "Error al desinstalar Python desde $($dir.FullName): $_" "ERROR"
            }
        }
    }
}

# 4. Desinstalar CUDA y componentes relacionados
Log-Action "Buscando instalaciones de CUDA..." "INFO"

$cudaInstalls = Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.Name -like "*NVIDIA*CUDA*" -or 
    $_.Name -like "*cuDNN*" -or
    $_.Name -like "*NVIDIA Graphics Driver*" -or
    $_.Name -like "*NVIDIA GPU Computing Toolkit*"
}

if ($cudaInstalls) {
    foreach ($cuda in $cudaInstalls) {
        Log-Action "Desinstalando $($cuda.Name)..." "INFO"
        try {
            $cuda.Uninstall() | Out-Null
            Log-Action "$($cuda.Name) desinstalado correctamente." "SUCCESS"
        }
        catch {
            Log-Action "Error al desinstalar $($cuda.Name): $_" "ERROR"
        }
    }
} else {
    Log-Action "No se encontraron instalaciones de CUDA por WMI." "INFO"
}

# Usar el desinstalador de NVIDIA
$nvidiaPaths = @(
    "${env:ProgramFiles}\NVIDIA GPU Computing Toolkit\CUDA\*\uninstall.exe",
    "${env:ProgramFiles}\NVIDIA Corporation\Uninstall*.exe"
)

foreach ($path in $nvidiaPaths) {
    $uninstallers = Get-Item -Path $path -ErrorAction SilentlyContinue
    foreach ($uninstaller in $uninstallers) {
        Log-Action "Ejecutando desinstalador NVIDIA: $($uninstaller.FullName)..." "INFO"
        try {
            Start-Process -FilePath $uninstaller.FullName -ArgumentList "-s" -Wait
            Log-Action "Proceso de desinstalación NVIDIA completado para $($uninstaller.FullName)." "SUCCESS"
        }
        catch {
            Log-Action "Error al ejecutar desinstalador NVIDIA $($uninstaller.FullName): $_" "ERROR"
        }
    }
}

# 5. Limpiar variables de entorno relacionadas
Log-Action "Limpiando variables de entorno..." "INFO"

$pathsToRemove = @(
    "*Python*",
    "*NVIDIA*",
    "*CUDA*",
    "*Visual Studio*",
    "*Microsoft Visual Studio*"
)

# Limpiar Path de usuario
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
foreach ($pathPattern in $pathsToRemove) {
    $newUserPath = ($userPath -split ';' | Where-Object { $_ -notlike $pathPattern }) -join ';'
    if ($newUserPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
        $userPath = $newUserPath
        Log-Action "Se removieron rutas que coinciden con '$pathPattern' de PATH de usuario." "SUCCESS"
    }
}

# Limpiar Path del sistema
$systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
foreach ($pathPattern in $pathsToRemove) {
    $newSystemPath = ($systemPath -split ';' | Where-Object { $_ -notlike $pathPattern }) -join ';'
    if ($newSystemPath -ne $systemPath) {
        [Environment]::SetEnvironmentVariable("PATH", $newSystemPath, "Machine")
        $systemPath = $newSystemPath
        Log-Action "Se removieron rutas que coinciden con '$pathPattern' de PATH del sistema." "SUCCESS"
    }
}

# Eliminar otras variables de entorno específicas
$envVarsToRemove = @(
    "CUDA_HOME",
    "CUDA_PATH",
    "CUDNN_PATH",
    "PYTHONHOME",
    "PYTHONPATH",
    "VS*"
)

foreach ($var in $envVarsToRemove) {
    $matchingVars = Get-ChildItem env: | Where-Object { $_.Name -like $var }
    foreach ($matchVar in $matchingVars) {
        [Environment]::SetEnvironmentVariable($matchVar.Name, $null, "User")
        [Environment]::SetEnvironmentVariable($matchVar.Name, $null, "Machine")
        Log-Action "Variable de entorno $($matchVar.Name) eliminada." "SUCCESS"
    }
}

# 6. Limpiar archivos residuales
Log-Action "Limpiando archivos residuales..." "INFO"

$foldersToRemove = @(
    "${env:ProgramFiles}\NVIDIA GPU Computing Toolkit",
    "${env:ProgramFiles}\NVIDIA Corporation",
    "${env:ProgramFiles}\Microsoft Visual Studio",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio",
    "${env:LocalAppData}\Microsoft\VisualStudio",
    "${env:LocalAppData}\Microsoft\Visual Studio",
    "${env:AppData}\Microsoft\VisualStudio",
    "${env:AppData}\Microsoft\Visual Studio",
    "${env:LocalAppData}\Programs\Python",
    "${env:AppData}\Python",
    "${env:LocalAppData}\pip",
    "${env:AppData}\pip"
)

foreach ($folder in $foldersToRemove) {
    if (Test-Path $folder) {
        Log-Action "Eliminando carpeta: $folder..." "INFO"
        try {
            Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
            Log-Action "Carpeta eliminada: $folder" "SUCCESS"
        }
        catch {
            Log-Action "Error al eliminar carpeta $folder: $_" "ERROR"
        }
    }
}

# 7. Limpiar registro
Log-Action "Limpiando entradas de registro..." "INFO"

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio",
    "HKLM:\SOFTWARE\NVIDIA Corporation",
    "HKLM:\SOFTWARE\Python"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Log-Action "Eliminando ruta de registro: $regPath..." "INFO"
        try {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
            Log-Action "Ruta de registro eliminada: $regPath" "SUCCESS"
        }
        catch {
            Log-Action "Error al eliminar ruta de registro $regPath: $_" "ERROR"
        }
    }
}

# 8. Limpiar caché de instaladores
Log-Action "Limpiando caché de instaladores..." "INFO"

$cacheFolders = @(
    "${env:LocalAppData}\pip\cache",
    "${env:LocalAppData}\Temp\pip-*",
    "${env:LocalAppData}\NuGet\Cache",
    "${env:LocalAppData}\Package Cache"
)

foreach ($folder in $cacheFolders) {
    $items = Get-Item -Path $folder -ErrorAction SilentlyContinue
    if ($items) {
        Log-Action "Eliminando caché: $folder..." "INFO"
        try {
            Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
            Log-Action "Caché eliminada: $folder" "SUCCESS"
        }
        catch {
            Log-Action "Error al eliminar caché $folder: $_" "ERROR"
        }
    }
}

# Reiniciar el servicio Windows Installer para liberar cualquier instalador en uso
Log-Action "Reiniciando el servicio Windows Installer..." "INFO"
try {
    Restart-Service -Name msiserver -Force
    Log-Action "Servicio Windows Installer reiniciado correctamente." "SUCCESS"
}
catch {
    Log-Action "Error al reiniciar el servicio Windows Installer: $_" "ERROR"
}

Log-Action "Proceso de limpieza completado." "SUCCESS"
Log-Action "Se recomienda reiniciar el sistema antes de ejecutar el script de instalación." "INFO"

Write-Host "`nLimpieza completada. Por favor, reinicia el sistema antes de continuar con la instalación." -ForegroundColor Green
