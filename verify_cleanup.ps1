# Script para verificar que todos los componentes han sido desinstalados correctamente
# Debe ejecutarse después del script cleanup.ps1 y antes de install.ps1

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script requiere privilegios de administrador. Por favor, ejecuta PowerShell como administrador."
    exit 1
}

# Configuración de visualización y registro detallado
$VerboseMode = $true  # Mostrar detalles completos de cada operación

# Función para registrar acciones en un archivo de log y en la consola
function Log-Action {
    param (
        [string]$Message,
        [string]$Type = "INFO",
        [bool]$ShowDetails = $false
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    Add-Content -Path "verify_cleanup_log.txt" -Value $logMessage -Force
    
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
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Función para ejecutar comandos con registro
function Execute-Command {
    param (
        [string]$Command,
        [string]$Description
    )
    
    Log-Action "Ejecutando: $Command" "COMMAND"
    Log-Action $Description "DEBUG"
    
    try {
        $output = Invoke-Expression -Command $Command -ErrorVariable errorMsg 2>&1
        
        if ($output) {
            foreach ($line in $output) {
                Log-Action "  > $line" "DEBUG"
            }
        }
        
        Log-Action "Comando ejecutado correctamente" "DEBUG"
        return $true
    }
    catch {
        Log-Action "Error al ejecutar el comando: $_" "ERROR"
        if ($errorMsg) {
            Log-Action "Detalles del error: $errorMsg" "ERROR"
        }
        return $false
    }
}

# Función para verificar si un programa está instalado por WMI
function Check-InstalledProgram {
    param (
        [string]$NamePattern,
        [string]$DisplayName
    )
    
    Log-Action "Verificando instalaciones de $DisplayName ($NamePattern)..." "INFO" $true
    
    $command = "Get-WmiObject -Class Win32_Product | Where-Object { `$_.Name -like '$NamePattern' }"
    Execute-Command -Command $command -Description "Buscar instalaciones por WMI"
    
    $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $NamePattern }
    
    if ($programs -and $programs.Count -gt 0) {
        Log-Action "❌ $DisplayName encontrado: $($programs.Count) instalación(es)" "ERROR" $true
        foreach ($prog in $programs) {
            Log-Action "   - $($prog.Name) (ID: $($prog.IdentifyingNumber))" "ERROR" $true
            Log-Action "     Versión: $($prog.Version)" "DEBUG"
            Log-Action "     Ruta: $($prog.InstallLocation)" "DEBUG"
        }
        return $false
    }
    else {
        Log-Action "✅ No se encontraron instalaciones de $DisplayName" "SUCCESS" $true
        return $true
    }
}

# Función para verificar si una carpeta existe
function Check-FolderExists {
    param (
        [string]$Path,
        [string]$DisplayName
    )
    
    Log-Action "Verificando carpeta de $DisplayName ($Path)..." "INFO" $true
    
    if (Test-Path $Path) {
        Log-Action "❌ Carpeta de $DisplayName encontrada: $Path" "ERROR" $true
        
        # Si está en modo verbose, mostrar algunos archivos de la carpeta
        if ($VerboseMode) {
            try {
                $command = "Get-ChildItem -Path '$Path' -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 5 | Format-Table -Property FullName"
                Execute-Command -Command $command -Description "Listar algunos archivos de la carpeta"
            }
            catch {
                Log-Action "No se pudieron listar los archivos: $_" "DEBUG"
            }
        }
        
        return $false
    }
    else {
        Log-Action "✅ No se encontró carpeta de $DisplayName" "SUCCESS" $true
        return $true
    }
}

# Función para verificar si una ruta está en PATH
function Check-PathEnv {
    param (
        [string]$NamePattern,
        [string]$DisplayName
    )
    
    Log-Action "Verificando $DisplayName en variables PATH..." "INFO" $true
    
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    $foundInUser = $false
    $foundInSystem = $false
    
    Log-Action "PATH de usuario: $userPath" "DEBUG"
    Log-Action "PATH de sistema: $systemPath" "DEBUG"
    
    $userPaths = $userPath -split ';' | Where-Object { $_ -like "*$NamePattern*" }
    $systemPaths = $systemPath -split ';' | Where-Object { $_ -like "*$NamePattern*" }
    
    if ($userPaths -and $userPaths.Count -gt 0) {
        $foundInUser = $true
        Log-Action "❌ $DisplayName encontrado en PATH de usuario:" "ERROR" $true
        foreach ($path in $userPaths) {
            Log-Action "   - $path" "ERROR" $true
        }
    }
    
    if ($systemPaths -and $systemPaths.Count -gt 0) {
        $foundInSystem = $true
        Log-Action "❌ $DisplayName encontrado en PATH del sistema:" "ERROR" $true
        foreach ($path in $systemPaths) {
            Log-Action "   - $path" "ERROR" $true
        }
    }
    
    if (-not $foundInUser -and -not $foundInSystem) {
        Log-Action "✅ No se encontró $DisplayName en las variables PATH" "SUCCESS" $true
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
    
    Log-Action "Verificando variable de entorno $DisplayName ($VarName)..." "INFO" $true
    
    $userVar = [Environment]::GetEnvironmentVariable($VarName, "User")
    $systemVar = [Environment]::GetEnvironmentVariable($VarName, "Machine")
    
    Log-Action "Valor en usuario: $userVar" "DEBUG"
    Log-Action "Valor en sistema: $systemVar" "DEBUG"
    
    if ($userVar) {
        Log-Action "❌ Variable de entorno $DisplayName ($VarName) encontrada en usuario: $userVar" "ERROR" $true
        return $false
    }
    
    if ($systemVar) {
        Log-Action "❌ Variable de entorno $DisplayName ($VarName) encontrada en sistema: $systemVar" "ERROR" $true
        return $false
    }
    
    Log-Action "✅ No se encontró variable de entorno $DisplayName ($VarName)" "SUCCESS" $true
    return $true
}

# Función para verificar comandos disponibles en CMD/PowerShell
function Check-CommandAvailable {
    param (
        [string]$Command,
        [string]$DisplayName
    )
    
    Log-Action "Verificando disponibilidad del comando $DisplayName ($Command)..." "INFO" $true
    
    try {
        $cmdResult = Get-Command $Command -ErrorAction Stop
        Log-Action "❌ Comando $DisplayName ($Command) disponible en PATH: $($cmdResult.Source)" "ERROR" $true
        return $false
    }
    catch {
        Log-Action "✅ Comando $DisplayName ($Command) no disponible en PATH" "SUCCESS" $true
        return $true
    }
}

# Función para verificar si una clave de registro existe
function Check-RegistryKey {
    param (
        [string]$Path,
        [string]$DisplayName
    )
    
    Log-Action "Verificando registro de $DisplayName ($Path)..." "INFO" $true
    
    if (Test-Path $Path) {
        Log-Action "❌ Registro de $DisplayName encontrado: $Path" "ERROR" $true
        
        # Si está en modo verbose, mostrar algunas claves del registro
        if ($VerboseMode) {
            try {
                $command = "Get-ChildItem -Path '$Path' -ErrorAction SilentlyContinue | Select-Object -First 5 | Format-Table -Property Name"
                Execute-Command -Command $command -Description "Listar algunas claves del registro"
            }
            catch {
                Log-Action "No se pudieron listar las claves del registro: $_" "DEBUG"
            }
        }
        
        return $false
    }
    else {
        Log-Action "✅ No se encontró registro de $DisplayName" "SUCCESS" $true
        return $true
    }
}

# Banner de inicio
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "           VERIFICADOR DE LIMPIEZA DEL ENTORNO DE DESARROLLO                " -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

Log-Action "Iniciando verificación de limpieza del sistema..." "INFO" $true

# Variables para el resultado final
$allClean = $true
$detailedResults = @{}

# Sección 1: Verificar Visual Studio
Log-Action "SECCIÓN 1: Verificando limpieza de Visual Studio..." "INFO" $true

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

Log-Action "Verificando carpetas comunes de Visual Studio..." "INFO" $true
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
$detailedResults["Visual Studio"] = @{
    "Clean" = $vsClean
    "Components" = @{
        "Instalación" = $vsCheck
        "Carpeta del instalador" = $vsInstallerCheck
        "Variables PATH" = $vsPathCheck
        "Carpetas comunes" = $vsFoldersCheck
        "Compilador C++" = $clCheck
        "MSBuild" = $msbuildCheck
    }
}

# Sección 2: Verificar Python
Log-Action "SECCIÓN 2: Verificando limpieza de Python..." "INFO" $true

$pythonCheck = Check-InstalledProgram -NamePattern "*Python*" -DisplayName "Python"
$pythonPathCheck = Check-PathEnv -NamePattern "Python" -DisplayName "Python"
$pythonHomeCheck = Check-EnvVar -VarName "PYTHONHOME" -DisplayName "Python Home"
$pythonPathVarCheck = Check-EnvVar -VarName "PYTHONPATH" -DisplayName "Python Path"

# Verificar carpetas comunes de Python
Log-Action "Verificando carpetas comunes de Python..." "INFO" $true
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
    Log-Action "Buscando carpetas que coinciden con '$folderPattern'..." "DEBUG"
    $folders = Get-Item -Path $folderPattern -ErrorAction SilentlyContinue
    
    if ($folders) {
        foreach ($folder in $folders) {
            $folderCheck = Check-FolderExists -Path $folder.FullName -DisplayName "Python ($($folder.FullName))"
            $pythonFoldersCheck = $pythonFoldersCheck -and $folderCheck
        }
    }
    else {
        Log-Action "✅ No se encontraron carpetas que coincidan con '$folderPattern'" "SUCCESS" $true
    }
}

# Verificar disponibilidad de comandos Python
$pythonCmdCheck = Check-CommandAvailable -Command "python" -DisplayName "Python"
$pipCmdCheck = Check-CommandAvailable -Command "pip" -DisplayName "Pip"

$pythonClean = $pythonCheck -and $pythonPathCheck -and $pythonHomeCheck -and $pythonPathVarCheck -and $pythonFoldersCheck -and $pythonCmdCheck -and $pipCmdCheck
$allClean = $allClean -and $pythonClean
$detailedResults["Python"] = @{
    "Clean" = $pythonClean
    "Components" = @{
        "Instalación" = $pythonCheck
        "Variables PATH" = $pythonPathCheck
        "Variable PYTHONHOME" = $pythonHomeCheck
        "Variable PYTHONPATH" = $pythonPathVarCheck
        "Carpetas comunes" = $pythonFoldersCheck
        "Comando Python" = $pythonCmdCheck
        "Comando Pip" = $pipCmdCheck
    }
}

# Sección 3: Verificar CUDA
Log-Action "SECCIÓN 3: Verificando limpieza de CUDA..." "INFO" $true

$cudaCheck = Check-InstalledProgram -NamePattern "*NVIDIA*CUDA*" -DisplayName "CUDA"
$cudnnCheck = Check-InstalledProgram -NamePattern "*cuDNN*" -DisplayName "cuDNN"
$cudaPathCheck = Check-PathEnv -NamePattern "CUDA" -DisplayName "CUDA"
$cudaHomeCheck = Check-EnvVar -VarName "CUDA_PATH" -DisplayName "CUDA Path"
$cudnnPathCheck = Check-EnvVar -VarName "CUDNN_PATH" -DisplayName "cuDNN Path"

# Verificar carpetas comunes de CUDA
Log-Action "Verificando carpetas comunes de CUDA..." "INFO" $true
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
$detailedResults["CUDA"] = @{
    "Clean" = $cudaClean
    "Components" = @{
        "Instalación CUDA" = $cudaCheck
        "Instalación cuDNN" = $cudnnCheck
        "Variables PATH" = $cudaPathCheck
        "Variable CUDA_PATH" = $cudaHomeCheck
        "Variable CUDNN_PATH" = $cudnnPathCheck
        "Carpetas comunes" = $cudaFoldersCheck
        "Comando NVCC" = $nvccCmdCheck
    }
}

# Sección 4: Verificar registros
Log-Action "SECCIÓN 4: Verificando registros..." "INFO" $true

$vsRegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\VisualStudio" -DisplayName "Visual Studio"
$vs64RegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio" -DisplayName "Visual Studio (64 bits)"
$cudaRegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\NVIDIA Corporation" -DisplayName "NVIDIA/CUDA"
$pythonRegCheck = Check-RegistryKey -Path "HKLM:\SOFTWARE\Python" -DisplayName "Python"

$registryClean = $vsRegCheck -and $vs64RegCheck -and $cudaRegCheck -and $pythonRegCheck
$allClean = $allClean -and $registryClean
$detailedResults["Registros"] = @{
    "Clean" = $registryClean
    "Components" = @{
        "Visual Studio" = $vsRegCheck
        "Visual Studio (64 bits)" = $vs64RegCheck
        "NVIDIA/CUDA" = $cudaRegCheck
        "Python" = $pythonRegCheck
    }
}

# Mostrar resumen
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "                           RESUMEN DE VERIFICACIÓN                                 " -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

# Mostrar resultados detallados
foreach ($category in $detailedResults.Keys) {
    $cleanStatus = $detailedResults[$category]["Clean"]
    Log-Action "$category limpio: $cleanStatus" -Type $(if ($cleanStatus) { "SUCCESS" } else { "ERROR" }) -ShowDetails $true
    
    if (-not $cleanStatus -and $VerboseMode) {
        Log-Action "Componentes que necesitan atención:" "WARNING" $true
        
        foreach ($component in $detailedResults[$category]["Components"].Keys) {
            $componentStatus = $detailedResults[$category]["Components"][$component]
            if (-not $componentStatus) {
                Log-Action "  ❌ $component" "ERROR" $true
            }
        }
        
        Log-Action "" "INFO"  # Línea en blanco para separar
    }
}

# Resultado final
if ($allClean) {
    Log-Action "`n✅ El sistema está limpio y listo para la instalación." "SUCCESS" $true
    Log-Action "Puedes proceder con el script de instalación (install.ps1)." "SUCCESS" $true
} else {
    Log-Action "`n❌ Se encontraron componentes que no se desinstalaron correctamente." "ERROR" $true
    Log-Action "Se recomienda limpiar manualmente estos componentes antes de proceder con la instalación." "WARNING" $true
    Log-Action "Consulta el archivo troubleshooting.md para obtener instrucciones de limpieza manual." "INFO" $true
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
if ($allClean) {
    Write-Host "                     VERIFICACIÓN EXITOSA                      " -ForegroundColor Green
} else {
    Write-Host "                     VERIFICACIÓN FALLIDA                      " -ForegroundColor Red
}
Write-Host "=================================================================`n" -ForegroundColor Cyan

# Mostrar siguientes pasos recomendados
if ($allClean) {
    Write-Host "Siguientes pasos recomendados:" -ForegroundColor Yellow
    Write-Host "1. Reiniciar el sistema"
    Write-Host "2. Ejecutar install.ps1 para instalar los componentes"
    Write-Host ""
    Write-Host "O simplemente ejecutar: python setup_environment.py --install`n"
} else {
    Write-Host "Para solucionar los problemas:" -ForegroundColor Yellow
    Write-Host "1. Ejecutar nuevamente cleanup.ps1 para intentar eliminar los componentes restantes"
    Write-Host "2. Realizar limpieza manual según troubleshooting.md"
    Write-Host "3. Ejecutar nuevamente verify_cleanup.ps1 para confirmar"
    Write-Host ""
    Write-Host "O si prefieres forzar la continuación (no recomendado):"
    Write-Host "  python setup_environment.py --install`n"
}

# Devolver código de salida
exit (if ($allClean) { 0 } else { 1 })
