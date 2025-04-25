# Script para limpiar completamente el entorno de desarrollo en Windows 11
# Desinstala Visual Studio, Python, CUDA, cuDNN y componentes relacionados

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
    
    Add-Content -Path "cleanup_log.txt" -Value $logMessage -Force
    
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

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "            LIMPIEZA DE ENTORNO DE DESARROLLO" -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan

Log-Action "¡ADVERTENCIA! Este script desinstalará completamente Visual Studio, Python, CUDA y componentes relacionados." "WARNING" $true
Log-Action "Asegúrate de haber hecho una copia de seguridad de tus proyectos y datos importantes." "WARNING" $true
$confirmation = Read-Host "¿Deseas continuar? (S/N)"
if ($confirmation -ne "S") {
    Log-Action "Operación cancelada por el usuario." "WARNING" $true
    exit 0
}

Log-Action "Iniciando proceso de limpieza del sistema..." "INFO" $true

# 1. Desinstalar versiones de Visual Studio
Log-Action "PASO 1: Desinstalando Visual Studio y componentes relacionados" "INFO" $true
Log-Action "Buscando instalaciones de Visual Studio..." "INFO" $true

# Buscar instalaciones de Visual Studio
$vsInstalls = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Visual Studio*" }
if ($vsInstalls) {
    Log-Action "Se encontraron $(($vsInstalls | Measure-Object).Count) instalaciones de Visual Studio" "INFO" $true
    foreach ($vs in $vsInstalls) {
        Log-Action "Desinstalando $($vs.Name)..." "INFO" $true
        Log-Action "ID: $($vs.IdentifyingNumber)" "DEBUG"
        Log-Action "Versión: $($vs.Version)" "DEBUG"
        Log-Action "Ruta: $($vs.InstallLocation)" "DEBUG"
        
        try {
            Log-Action "Iniciando desinstalación de $($vs.Name)" "COMMAND"
            $vs.Uninstall() | Out-Null
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
            $command = "Start-Process -FilePath '$vsInstallerPath' -ArgumentList 'uninstall --all --force' -Wait -PassThru"
            $result = Execute-Command -Command $command -Description "Desinstalación de todas las instancias de Visual Studio"
            
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

# 2. Desinstalar Build Tools y otros componentes de Visual Studio
Log-Action "PASO 2: Desinstalando Build Tools y componentes de desarrollo" "INFO" $true
Log-Action "Buscando Build Tools y componentes de Visual Studio..." "INFO" $true

$buildTools = Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.Name -like "*Build Tools*" -or 
    $_.Name -like "*Microsoft Visual C++*" -or
    $_.Name -like "*Microsoft .NET*" -or
    $_.Name -like "*Windows SDK*"
}

if ($buildTools) {
    Log-Action "Se encontraron $(($buildTools | Measure-Object).Count) componentes de Build Tools" "INFO" $true
    foreach ($bt in $buildTools) {
        Log-Action "Desinstalando $($bt.Name)..." "INFO" $true
        Log-Action "ID: $($bt.IdentifyingNumber)" "DEBUG"
        Log-Action "Versión: $($bt.Version)" "DEBUG"
        Log-Action "Ruta: $($bt.InstallLocation)" "DEBUG"
        
        try {
            Log-Action "Iniciando desinstalación de $($bt.Name)" "COMMAND"
            $bt.Uninstall() | Out-Null
            Log-Action "$($bt.Name) desinstalado correctamente." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al desinstalar $($bt.Name): $_" "ERROR" $true
        }
    }
} else {
    Log-Action "No se encontraron Build Tools por WMI." "INFO" $true
}

# 3. Desinstalar versiones de Python
Log-Action "PASO 3: Desinstalando Python y componentes relacionados" "INFO" $true
Log-Action "Buscando instalaciones de Python..." "INFO" $true

# Buscar instalaciones de Python usando WMI
$pythonInstalls = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Python*" }
if ($pythonInstalls) {
    Log-Action "Se encontraron $(($pythonInstalls | Measure-Object).Count) instalaciones de Python por WMI" "INFO" $true
    foreach ($python in $pythonInstalls) {
        Log-Action "Desinstalando $($python.Name)..." "INFO" $true
        Log-Action "ID: $($python.IdentifyingNumber)" "DEBUG"
        Log-Action "Versión: $($python.Version)" "DEBUG"
        Log-Action "Ruta: $($python.InstallLocation)" "DEBUG"
        
        try {
            Log-Action "Iniciando desinstalación de $($python.Name)" "COMMAND"
            $python.Uninstall() | Out-Null
            Log-Action "$($python.Name) desinstalado correctamente." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al desinstalar $($python.Name): $_" "ERROR" $true
        }
    }
} else {
    Log-Action "No se encontraron instalaciones de Python por WMI." "INFO" $true
}

# Buscar instalaciones de Python por rutas comunes
Log-Action "Buscando instalaciones de Python en rutas comunes..." "INFO" $true
$pythonPaths = @(
    "${env:ProgramFiles}\Python*",
    "${env:ProgramFiles(x86)}\Python*",
    "${env:LocalAppData}\Programs\Python\Python*"
)

$pythonFound = $false
foreach ($path in $pythonPaths) {
    $pythonDirs = Get-Item -Path $path -ErrorAction SilentlyContinue
    foreach ($dir in $pythonDirs) {
        $pythonFound = $true
        Log-Action "Instalación de Python encontrada en: $($dir.FullName)" "INFO" $true
        
        $uninstallPath = Join-Path -Path $dir.FullName -ChildPath "uninstall.exe"
        if (Test-Path $uninstallPath) {
            Log-Action "Desinstalando Python desde $($dir.FullName)..." "INFO" $true
            
            try {
                $command = "Start-Process -FilePath '$uninstallPath' -ArgumentList '/quiet' -Wait -PassThru"
                $result = Execute-Command -Command $command -Description "Desinstalación silenciosa de Python"
                
                if ($result) {
                    Log-Action "Python desde $($dir.FullName) desinstalado correctamente." "SUCCESS" $true
                } else {
                    Log-Action "La desinstalación de Python puede haber tenido problemas." "WARNING" $true
                }
            }
            catch {
                Log-Action "Error al desinstalar Python desde $($dir.FullName): $_" "ERROR" $true
            }
        } else {
            Log-Action "No se encontró uninstall.exe en $($dir.FullName)" "WARNING" $true
            Log-Action "Intentando eliminar la carpeta directamente..." "INFO" $true
            
            try {
                $command = "Remove-Item -Path '$($dir.FullName)' -Recurse -Force -ErrorAction Stop"
                $result = Execute-Command -Command $command -Description "Eliminación forzada de carpeta Python"
                
                if ($result) {
                    Log-Action "Carpeta de Python eliminada: $($dir.FullName)" "SUCCESS" $true
                } else {
                    Log-Action "No se pudo eliminar la carpeta $($dir.FullName)" "WARNING" $true
                }
            }
            catch {
                Log-Action "Error al eliminar carpeta $($dir.FullName): $_" "ERROR" $true
            }
        }
    }
}

if (-not $pythonFound) {
    Log-Action "No se encontraron carpetas de Python en rutas comunes." "INFO" $true
}

# 4. Desinstalar CUDA y componentes relacionados
Log-Action "PASO 4: Desinstalando CUDA, cuDNN y componentes NVIDIA" "INFO" $true
Log-Action "Buscando instalaciones de CUDA..." "INFO" $true

$cudaInstalls = Get-WmiObject -Class Win32_Product | Where-Object { 
    $_.Name -like "*NVIDIA*CUDA*" -or 
    $_.Name -like "*cuDNN*" -or
    $_.Name -like "*NVIDIA Graphics Driver*" -or
    $_.Name -like "*NVIDIA GPU Computing Toolkit*"
}

if ($cudaInstalls) {
    Log-Action "Se encontraron $(($cudaInstalls | Measure-Object).Count) componentes de CUDA/NVIDIA" "INFO" $true
    foreach ($cuda in $cudaInstalls) {
        Log-Action "Desinstalando $($cuda.Name)..." "INFO" $true
        Log-Action "ID: $($cuda.IdentifyingNumber)" "DEBUG"
        Log-Action "Versión: $($cuda.Version)" "DEBUG"
        Log-Action "Ruta: $($cuda.InstallLocation)" "DEBUG"
        
        try {
            Log-Action "Iniciando desinstalación de $($cuda.Name)" "COMMAND"
            $cuda.Uninstall() | Out-Null
            Log-Action "$($cuda.Name) desinstalado correctamente." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al desinstalar $($cuda.Name): $_" "ERROR" $true
        }
    }
} else {
    Log-Action "No se encontraron instalaciones de CUDA por WMI." "INFO" $true
}

# Usar el desinstalador de NVIDIA
Log-Action "Buscando desinstaladores específicos de NVIDIA..." "INFO" $true
$nvidiaPaths = @(
    "${env:ProgramFiles}\NVIDIA GPU Computing Toolkit\CUDA\*\uninstall.exe",
    "${env:ProgramFiles}\NVIDIA Corporation\Uninstall*.exe"
)

$nvidiaUninstallerFound = $false
foreach ($path in $nvidiaPaths) {
    $uninstallers = Get-Item -Path $path -ErrorAction SilentlyContinue
    foreach ($uninstaller in $uninstallers) {
        $nvidiaUninstallerFound = $true
        Log-Action "Desinstalador NVIDIA encontrado: $($uninstaller.FullName)" "INFO" $true
        Log-Action "Ejecutando desinstalador NVIDIA: $($uninstaller.FullName)..." "INFO" $true
        
        try {
            $command = "Start-Process -FilePath '$($uninstaller.FullName)' -ArgumentList '-s' -Wait -PassThru"
            $result = Execute-Command -Command $command -Description "Desinstalación silenciosa de componente NVIDIA"
            
            if ($result) {
                Log-Action "Proceso de desinstalación NVIDIA completado para $($uninstaller.FullName)." "SUCCESS" $true
            } else {
                Log-Action "La desinstalación NVIDIA puede haber tenido problemas." "WARNING" $true
            }
        }
        catch {
            Log-Action "Error al ejecutar desinstalador NVIDIA $($uninstaller.FullName): $_" "ERROR" $true
        }
    }
}

if (-not $nvidiaUninstallerFound) {
    Log-Action "No se encontraron desinstaladores específicos de NVIDIA." "INFO" $true
}

# 5. Limpiar variables de entorno relacionadas
Log-Action "PASO 5: Limpiando variables de entorno" "INFO" $true
Log-Action "Identificando variables de entorno relacionadas..." "INFO" $true

$pathsToRemove = @(
    "*Python*",
    "*NVIDIA*",
    "*CUDA*",
    "*Visual Studio*",
    "*Microsoft Visual Studio*"
)

# Limpiar Path de usuario
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
Log-Action "PATH de usuario actual: $userPath" "DEBUG"

foreach ($pathPattern in $pathsToRemove) {
    Log-Action "Buscando entradas que coinciden con '$pathPattern' en PATH de usuario..." "DEBUG"
    $pathsToKeep = @()
    $pathsRemoved = @()
    
    foreach ($path in ($userPath -split ';')) {
        if ($path -like $pathPattern) {
            $pathsRemoved += $path
        } else {
            $pathsToKeep += $path
        }
    }
    
    if ($pathsRemoved.Count -gt 0) {
        $newUserPath = $pathsToKeep -join ';'
        
        Log-Action "Removiendo las siguientes rutas de PATH de usuario:" "INFO" $true
        foreach ($removed in $pathsRemoved) {
            Log-Action "  - $removed" "INFO" $true
        }
        
        try {
            Log-Action "Actualizando PATH de usuario..." "COMMAND"
            [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
            $userPath = $newUserPath
            Log-Action "Se removieron rutas que coinciden con '$pathPattern' de PATH de usuario." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al actualizar PATH de usuario: $_" "ERROR" $true
        }
    }
    else {
        Log-Action "No se encontraron rutas que coincidan con '$pathPattern' en PATH de usuario." "DEBUG"
    }
}

# Limpiar Path del sistema
$systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
Log-Action "PATH del sistema actual: $systemPath" "DEBUG"

foreach ($pathPattern in $pathsToRemove) {
    Log-Action "Buscando entradas que coinciden con '$pathPattern' en PATH del sistema..." "DEBUG"
    $pathsToKeep = @()
    $pathsRemoved = @()
    
    foreach ($path in ($systemPath -split ';')) {
        if ($path -like $pathPattern) {
            $pathsRemoved += $path
        } else {
            $pathsToKeep += $path
        }
    }
    
    if ($pathsRemoved.Count -gt 0) {
        $newSystemPath = $pathsToKeep -join ';'
        
        Log-Action "Removiendo las siguientes rutas de PATH del sistema:" "INFO" $true
        foreach ($removed in $pathsRemoved) {
            Log-Action "  - $removed" "INFO" $true
        }
        
        try {
            Log-Action "Actualizando PATH del sistema..." "COMMAND"
            [Environment]::SetEnvironmentVariable("PATH", $newSystemPath, "Machine")
            $systemPath = $newSystemPath
            Log-Action "Se removieron rutas que coinciden con '$pathPattern' de PATH del sistema." "SUCCESS" $true
        }
        catch {
            Log-Action "Error al actualizar PATH del sistema: $_" "ERROR" $true
        }
    }
    else {
        Log-Action "No se encontraron rutas que coincidan con '$pathPattern' en PATH del sistema." "DEBUG"
    }
}

# Eliminar otras variables de entorno específicas
Log-Action "Buscando otras variables de entorno específicas..." "INFO" $true
$envVarsToRemove = @(
    "CUDA_HOME",
    "CUDA_PATH",
    "CUDNN_PATH",
    "PYTHONHOME",
    "PYTHONPATH",
    "VS*"
)

foreach ($varPattern in $envVarsToRemove) {
    Log-Action "Buscando variables que coinciden con '$varPattern'..." "DEBUG"
    $matchingVars = Get-ChildItem env: | Where-Object { $_.Name -like $varPattern }
    
    if ($matchingVars) {
        Log-Action "Encontradas $(($matchingVars | Measure-Object).Count) variables que coinciden con '$varPattern'" "INFO" $true
        
        foreach ($matchVar in $matchingVars) {
            Log-Action "Eliminando variable de entorno $($matchVar.Name) = $($matchVar.Value)" "INFO" $true
            
            try {
                Log-Action "Eliminando variable de usuario $($matchVar.Name)..." "COMMAND"
                [Environment]::SetEnvironmentVariable($matchVar.Name, $null, "User")
                
                Log-Action "Eliminando variable de sistema $($matchVar.Name)..." "COMMAND"
                [Environment]::SetEnvironmentVariable($matchVar.Name, $null, "Machine")
                
                Log-Action "Variable de entorno $($matchVar.Name) eliminada." "SUCCESS" $true
            }
            catch {
                Log-Action "Error al eliminar variable $($matchVar.Name): $_" "ERROR" $true
            }
        }
    }
    else {
        Log-Action "No se encontraron variables que coinciden con '$varPattern'." "DEBUG"
    }
}

# 6. Limpiar archivos residuales
Log-Action "PASO 6: Limpiando archivos residuales" "INFO" $true
Log-Action "Buscando carpetas residuales..." "INFO" $true

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
        Log-Action "Carpeta encontrada: $folder" "INFO" $true
        Log-Action "Eliminando carpeta: $folder..." "INFO" $true
        
        try {
            $command = "Remove-Item -Path '$folder' -Recurse -Force -ErrorAction Stop"
            $result = Execute-Command -Command $command -Description "Eliminación forzada de carpeta residual"
            
            if ($result) {
                Log-Action "Carpeta eliminada: $folder" "SUCCESS" $true
            } else {
                Log-Action "La carpeta $folder no pudo ser eliminada completamente" "WARNING" $true
            }
        }
        catch {
            Log-Action "Error al eliminar carpeta $folder: $_" "ERROR" $true
            
            # Intentar listar los archivos que están causando problemas
            Log-Action "Intentando identificar archivos bloqueados..." "DEBUG"
            try {
                $command = "Get-ChildItem -Path '$folder' -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 10 | Format-Table -Property FullName"
                Execute-Command -Command $command -Description "Listar archivos problemáticos"
            }
            catch {
                Log-Action "No se pudieron listar los archivos problemáticos: $_" "DEBUG"
            }
        }
    }
    else {
        Log-Action "Carpeta no encontrada: $folder" "DEBUG"
    }
}

# 7. Limpiar registro
Log-Action "PASO 7: Limpiando entradas de registro" "INFO" $true
Log-Action "Buscando entradas de registro relacionadas..." "INFO" $true

$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio",
    "HKLM:\SOFTWARE\NVIDIA Corporation",
    "HKLM:\SOFTWARE\Python"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Log-Action "Ruta de registro encontrada: $regPath" "INFO" $true
        Log-Action "Eliminando ruta de registro: $regPath..." "INFO" $true
        
        try {
            $command = "Remove-Item -Path '$regPath' -Recurse -Force -ErrorAction Stop"
            $result = Execute-Command -Command $command -Description "Eliminación forzada de clave de registro"
            
            if ($result) {
                Log-Action "Ruta de registro eliminada: $regPath" "SUCCESS" $true
            } else {
                Log-Action "La ruta de registro $regPath no pudo ser eliminada completamente" "WARNING" $true
            }
        }
        catch {
            Log-Action "Error al eliminar ruta de registro $regPath: $_" "ERROR" $true
        }
    }
    else {
        Log-Action "Ruta de registro no encontrada: $regPath" "DEBUG"
    }
}

# 8. Limpiar caché de instaladores
Log-Action "PASO 8: Limpiando caché de instaladores" "INFO" $true
Log-Action "Buscando carpetas de caché..." "INFO" $true

$cacheFolders = @(
    "${env:LocalAppData}\pip\cache",
    "${env:LocalAppData}\Temp\pip-*",
    "${env:LocalAppData}\NuGet\Cache",
    "${env:LocalAppData}\Package Cache"
)

foreach ($folderPattern in $cacheFolders) {
    Log-Action "Buscando carpetas que coinciden con '$folderPattern'..." "DEBUG"
    $items = Get-Item -Path $folderPattern -ErrorAction SilentlyContinue
    
    if ($items) {
        Log-Action "Carpetas de caché encontradas para el patrón '$folderPattern'" "INFO" $true
        
        foreach ($item in $items) {
            Log-Action "Eliminando caché: $($item.FullName)..." "INFO" $true
            
            try {
                $command = "Remove-Item -Path '$($item.FullName)' -Recurse -Force -ErrorAction Stop"
                $result = Execute-Command -Command $command -Description "Eliminación forzada de carpeta de caché"
                
                if ($result) {
                    Log-Action "Caché eliminada: $($item.FullName)" "SUCCESS" $true
                } else {
                    Log-Action "La carpeta de caché $($item.FullName) no pudo ser eliminada completamente" "WARNING" $true
                }
            }
            catch {
                Log-Action "Error al eliminar caché $($item.FullName): $_" "ERROR" $true
            }
        }
    }
    else {
        Log-Action "No se encontraron carpetas que coincidan con '$folderPattern'." "DEBUG"
    }
}

# Reiniciar el servicio Windows Installer para liberar cualquier instalador en uso
Log-Action "PASO 9: Reiniciando servicios del sistema" "INFO" $true
Log-Action "Reiniciando el servicio Windows Installer..." "INFO" $true

try {
    $command = "Restart-Service -Name msiserver -Force"
    $result = Execute-Command -Command $command -Description "Reinicio de servicio Windows Installer"
    
    if ($result) {
        Log-Action "Servicio Windows Installer reiniciado correctamente." "SUCCESS" $true
    } else {
        Log-Action "El servicio Windows Installer no pudo ser reiniciado" "WARNING" $true
    }
}
catch {
    Log-Action "Error al reiniciar el servicio Windows Installer: $_" "ERROR" $true
}

Log-Action "RESUMEN DE LA LIMPIEZA DEL SISTEMA" "INFO" $true
Log-Action "Proceso de limpieza completado." "SUCCESS" $true
Log-Action "Se recomienda ejecutar el verificador de limpieza (verify_cleanup.ps1) para comprobar que todos los componentes se han eliminado correctamente." "INFO" $true
Log-Action "También se recomienda reiniciar el sistema antes de ejecutar el script de instalación." "INFO" $true

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host "                    LIMPIEZA COMPLETADA" -ForegroundColor Cyan
Write-Host "=================================================================`n" -ForegroundColor Cyan
Write-Host "Ejecución siguiente recomendada:" -ForegroundColor Yellow
Write-Host "1. Ejecutar verify_cleanup.ps1 para verificar la limpieza"
Write-Host "2. Reiniciar el sistema"
Write-Host "3. Ejecutar install.ps1 para instalar los componentes"
Write-Host "`nO simplemente ejecutar: python setup_environment.py --full`n"
