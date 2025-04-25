# Script para verificar que todos los componentes han sido desinstalados correctamente
# Debe ejecutarse después del script cleanup.ps1 y antes de install.ps1

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

# Función para registrar acciones en un archivo de log
function Log-Action {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path "verify_cleanup_log.txt" -Value $logMessage -Force
    
    switch ($Type) {
        "INFO" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Función para verificar si un programa está instalado por WMI
function Check-InstalledProgram {
    param (
        [string]$NamePattern,
        [string]$DisplayName
    )
    
    $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $NamePattern }
    if ($programs -and $programs.Count -gt 0) {
        Log-Action "❌ $DisplayName encontrado: $($programs.Count) instalación(es)" "ERROR"
        foreach ($prog in $programs) {
            Log-Action "   - $($prog.Name) (ID: $($prog.IdentifyingNumber))" "INFO"
        }
        return $false
    }
    else {
        Log-Action "✅ No se encontraron instalaciones de $DisplayName" "SUCCESS"
        return $true
    }
}

# Función para verificar si una carpeta existe
function Check-FolderExists {
    param (
        [string]$Path,
        [string]$DisplayName
    )
    
    if (Test-Path $Path) {
        Log-Action "❌ Carpeta de $DisplayName encontrada: $Path" "ERROR"
        return $false
    }
    else {
        Log-Action "✅ No se encontró carpeta de $DisplayName" "SUCCESS"
        return $true
    }
}

# Función para verificar si una ruta está en PATH
function Check-PathEnv {
    param (
        [string]$NamePattern,
        [string]$DisplayName
    )
    
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    $foundInUser = $false
    $foundInSystem = $false
    
    $userPaths = $userPath -split ';' | Where-Object { $_ -like "*$NamePattern*" }
    $systemPaths = $systemPath -split ';' | Where-Object { $_ -like "*$NamePattern*" }
    
    if ($userPaths -and $userPaths.Count -gt 0) {
        $foundInUser = $true
        Log-Action "❌ $DisplayName encontrado en PATH de usuario:" "ERROR"
        foreach ($path in $userPaths) {
            Log-Action "   - $path" "INFO"
        }
    }
    
    if ($systemPaths -and $systemPaths.Count -gt 0) {
        $foundInSystem = $true
        Log-Action "❌ $DisplayName encontrado en PATH del sistema:" "ERROR"
        foreach ($path in $systemPaths) {
            Log-Action "   - $path" "INFO"
        }
    }
    
    if (-not $foundInUser -and -not $foundInSystem) {
        Log-Action "✅ No se encontró $DisplayName en las variables PATH" "SUCCESS"
        return $true
    }
    
    return $false
}

# Función para verificar si una variable de entorno existe
function Check-EnvVar {
    param (
        [string]$VarName,
        [string]$DisplayName
    )
    
    $userVar = [Environment]::GetEnvironmentVariable($VarName, "User")
    $systemVar = [Environment]::GetEnvironmentVariable($VarName, "Machine")
    
    if ($userVar) {
        Log-Action "❌ Variable de entorno $DisplayName ($VarName) encontrada en usuario: $userVar" "ERROR"
        return $false
    }
    
    if ($systemVar) {
        Log-Action "❌ Variable de entorno $DisplayName ($VarName) encontrada en sistema: $systemVar" "ERROR"
        return $false
    }
    
    Log-Action "✅ No se encontró variable de entorno $DisplayName ($VarName)" "SUCCESS"
    return $true
}

# Función para verificar comandos disponibles en CMD/PowerShell
function Check-CommandAvailable {
    param (
        [string]$Command,
        [string]$DisplayName
    )
    
    try {
        $null = Get-Command $Command -ErrorAction Stop
        Log-Action "❌ Comando $DisplayName ($Command) disponible en PATH" "ERROR"
        return $false
    }
    catch {
        Log-Action "✅ Comando $DisplayName ($Command) no disponible en PATH" "SUCCESS"
        return $true
    }
}

# Banner de inicio
Write-Host "`n========================================================================================" -ForegroundColor Cyan
Write-Host "           VERIFICADOR DE LIMPIEZA DEL ENTORNO DE DESARROLLO PARA IA/ML                " -ForegroundColor Cyan
Write-Host "========================================================================================`n" -ForegroundColor Cyan

Log-Action "Iniciando verificación de limpieza del sistema..." "INFO"

# Variables para el resultado final
$allClean = $true

# Sección 1: Verificar Visual Studio
Log-Action "Verificando limpieza de Visual Studio..." "INFO"

$vsCheck = Check-InstalledProgram -NamePattern "*Visual Studio*" -DisplayName "Visual Studio"
$vsInstallerCheck = Check-FolderExists -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer" -DisplayName "Visual Studio Installer"
$vsPathCheck = Check-PathEnv -NamePattern "Visual Studio" -DisplayName "Visual Studio"

# Verificar carpetas comunes de Visual Studio
$vsFolders = @(
    "${env:ProgramFiles}\Microsoft Visual Studio",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio",
    "${env:LocalAppData}\Microsoft\VisualStudio",
    "${env:LocalAppData}\Microsoft\Visual Studio",
    "${env:AppData}\Microsoft\VisualStudio",
    "${env:AppData}\Microsoft\Visual Studio"
)

$vsFoldersCheck = $true
foreach ($folder in $vsFolders) {
    $folderCheck = Check-FolderExists -Path $folder -DisplayName "Visual Studio ($folder)"
    $vsFoldersCheck = $vsFoldersCheck -and $folderCheck
}

# Verificar disponibilidad de compiladores
$clCheck = Check-CommandAvailable -Command "cl" -DisplayName "Compilador C++"
$msbuildCheck = Check-CommandAvailable -Command "msbuild" -DisplayName "MSBuild"

$vsClean = $vsCheck -and $vsInstallerCheck -and $vsPathCheck -and $vsFoldersCheck -and $clCheck -and $msbuildCheck
$allClean = $allClean -and $vsClean

# Sección 2: Verificar Python
Log-Action "`nVerificando limpieza de Python..." "INFO"

$pythonCheck = Check-InstalledProgram -NamePattern "*Python*" -DisplayName "Python"
$pythonPathCheck = Check-PathEnv -NamePattern "Python" -DisplayName "Python"
$pythonHomeCheck = Check-EnvVar -VarName "PYTHONHOME" -DisplayName "Python Home"
$pythonPathVarCheck = Check-EnvVar -VarName "PYTHONPATH" -DisplayName "Python Path"

# Verificar carpetas comunes de Python
$pythonFolders = @(
    "${env:ProgramFiles}\Python*",
    "${env:ProgramFiles(x86)}\Python*",
    "${env:LocalAppData}\Programs\Python\Python*",
    "${env:AppData}\Python",
    "${env:LocalAppData}\pip",
    "${env:AppData}\pip"
)

$pythonFoldersCheck = $true
foreach ($folderPattern in $pythonFolders) {
    $folders = Get-Item -Path $folderPattern -ErrorAction SilentlyContinue
    foreach ($folder in $folders) {
        $folderCheck = Check-FolderExists -Path $folder.FullName -DisplayName "Python ($($folder.FullName))"
        $pythonFoldersCheck = $pythonFoldersCheck -and $folderCheck
    }
}

# Verificar disponibilidad de comandos Python
$pythonCmdCheck = Check-CommandAvailable -Command "python" -DisplayName "Python"
$pipCmdCheck = Check-CommandAvailable -Command "pip" -DisplayName "Pip"

$pythonClean = $pythonCheck -and $pythonPathCheck -and $pythonHomeCheck -and $pythonPathVarCheck -and $pythonFoldersCheck -and $pythonCmdCheck -and $pipCmdCheck
$allClean = $allClean -and $pythonClean

# Sección 3: Verificar CUDA
Log-Action "`nVerificando limpieza de CUDA..." "INFO"

$cudaCheck = Check-InstalledProgram -NamePattern "*NVIDIA*CUDA*" -DisplayName "CUDA"
$cudnnCheck = Check-InstalledProgram -NamePattern "*cuDNN*" -DisplayName "cuDNN"
$cudaPathCheck = Check-PathEnv -NamePattern "CUDA" -DisplayName "CUDA"
$cudaHomeCheck = Check-EnvVar -VarName "CUDA_PATH" -DisplayName "CUDA Path"
$cudnnPathCheck = Check-EnvVar -VarName "CUDNN_PATH" -DisplayName "cuDNN Path"

# Verificar carpetas comunes de CUDA
$cudaFolders = @(
    "${env:ProgramFiles}\NVIDIA GPU Computing Toolkit",
    "${env:ProgramFiles}\NVIDIA Corporation",
    "${env:ProgramW6432}\NVIDIA GPU Computing Toolkit",
    "${env:ProgramW6432}\NVIDIA Corporation",
    "${env:ProgramFiles(x86)}\NVIDIA Corporation"
)

$cudaFoldersCheck = $true
foreach ($folder in $cudaFolders) {
    $folderCheck = Check-FolderExists -Path $folder -DisplayName "CUDA/NVIDIA ($folder)"
    $cudaFoldersCheck = $cudaFoldersCheck -and $folderCheck
}

# Verificar disponibilidad de comandos CUDA
$nvccCmdCheck = Check-CommandAvailable -Command "nvcc" -DisplayName "NVCC (Compilador CUDA)"
$nvidiaSmiCmdCheck = Check-CommandAvailable -Command "nvidia-smi" -DisplayName "NVIDIA-SMI"
# Nota: nvidia-smi puede estar disponible incluso después de desinstalar CUDA si los controladores NVIDIA están presentes

$cudaClean = $cudaCheck -and $cudnnCheck -and $cudaPathCheck -and $cudaHomeCheck -and $cudnnPathCheck -and $cudaFoldersCheck -and $nvccCmdCheck
$allClean = $allClean -and $cudaClean

# Sección 4: Verificar registros
Log-Action "`nVerificando registros..." "INFO"

# Esta función verifica si una clave de registro existe
function Check-RegistryKey {
    param (
        [string]$Path,
        [string]$DisplayName
    )
    
    if (Test-Path $Path) {
        Log-Action "❌ Registro de $DisplayName encontrado: $Path" "ERROR"
        return $false
    }
    else {
        Log-Action "✅ No se encontró registro de $DisplayName" "SUCCESS"
        return $true
    }
}

$vsRegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\VisualStudio" -DisplayName "Visual Studio"
$vs64RegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio" -DisplayName "Visual Studio (64 bits)"
$cudaRegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\NVIDIA Corporation" -DisplayName "NVIDIA/CUDA"
$pythonRegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\Python" -DisplayName "Python"

$registryClean = $vsRegCheck -and $vs64RegCheck -and $cudaRegCheck -and $pythonRegCheck
$allClean = $allClean -and $registryClean

# Mostrar resumen
Write-Host "`n========================================================================================" -ForegroundColor Cyan
Write-Host "                               RESUMEN DE VERIFICACIÓN                                 " -ForegroundColor Cyan
Write-Host "========================================================================================`n" -ForegroundColor Cyan

Log-Action "Visual Studio limpio: $vsClean" -Type $(if ($vsClean) { "SUCCESS" } else { "ERROR" })
Log-Action "Python limpio: $pythonClean" -Type $(if ($pythonClean) { "SUCCESS" } else { "ERROR" })
Log-Action "CUDA limpio: $cudaClean" -Type $(if ($cudaClean) { "SUCCESS" } else { "ERROR" })
Log-Action "Registros limpios: $registryClean" -Type $(if ($registryClean) { "SUCCESS" } else { "ERROR" })

# Resultado final
if ($allClean) {
    Log-Action "`n✅ El sistema está limpio y listo para la instalación." "SUCCESS"
    Log-Action "Puedes proceder con el script de instalación (install.ps1)." "SUCCESS"
} else {
    Log-Action "`n❌ Se encontraron componentes que no se desinstalaron correctamente." "ERROR"
    Log-Action "Se recomienda limpiar manualmente estos componentes antes de proceder con la instalación." "WARNING"
    Log-Action "Consulta el archivo troubleshooting.md para obtener instrucciones de limpieza manual." "INFO"
}

# Devolver código de salida
exit (if ($allClean) { 0 } else { 1 })
