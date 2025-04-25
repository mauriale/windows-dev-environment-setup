# Script auxiliar para instalar cuDNN en Windows 11
# Debe ejecutarse después de descargar manualmente el paquete cuDNN desde NVIDIA

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
    
    Add-Content -Path "cudnn_install_log.txt" -Value $logMessage -Force
    
    switch ($Type) {
        "INFO" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Solicitar ruta al archivo ZIP o TAR.GZ de cuDNN
Log-Action "Este script ayuda a instalar cuDNN después de descargarlo manualmente de la web de NVIDIA." "INFO"
Log-Action "Primero, necesitas descargar cuDNN desde: https://developer.nvidia.com/cudnn" "INFO"
Log-Action "Se requiere una cuenta NVIDIA Developer (gratuita) para descargar cuDNN." "INFO"
Log-Action "Asegúrate de descargar la versión compatible con CUDA 12.4" "INFO"

$cudnnZipPath = Read-Host "Ingresa la ruta completa al archivo ZIP o TAR.GZ de cuDNN descargado"

if (-not (Test-Path $cudnnZipPath)) {
    Log-Action "El archivo especificado no existe: $cudnnZipPath" "ERROR"
    exit 1
}

# Crear carpeta temporal para extracción
$tempFolder = Join-Path $env:TEMP "cudnn_extract"
if (Test-Path $tempFolder) {
    Remove-Item -Path $tempFolder -Recurse -Force
}
New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null

# Detectar formato del archivo
$fileExtension = [System.IO.Path]::GetExtension($cudnnZipPath).ToLower()

# Extracción del archivo
Log-Action "Extrayendo cuDNN en carpeta temporal..." "INFO"
if ($fileExtension -eq ".zip") {
    # Extraer ZIP
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($cudnnZipPath, $tempFolder)
        Log-Action "Archivo ZIP extraído correctamente." "SUCCESS"
    }
    catch {
        Log-Action "Error al extraer archivo ZIP: $_" "ERROR"
        exit 1
    }
}
elseif ($fileExtension -eq ".gz" -or $fileExtension -eq ".tgz") {
    # Extraer TAR.GZ
    try {
        # Verificar si 7-Zip está instalado
        $sevenZipPath = "${env:ProgramFiles}\7-Zip\7z.exe"
        if (-not (Test-Path $sevenZipPath)) {
            Log-Action "7-Zip no encontrado. Intentando descargar e instalar..." "WARNING"
            
            # Descargar e instalar 7-Zip
            $sevenZipUrl = "https://www.7-zip.org/a/7z2107-x64.exe"
            $sevenZipInstaller = Join-Path $env:TEMP "7z-installer.exe"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($sevenZipUrl, $sevenZipInstaller)
            
            Start-Process -FilePath $sevenZipInstaller -ArgumentList "/S" -Wait
            
            if (-not (Test-Path $sevenZipPath)) {
                Log-Action "No se pudo instalar 7-Zip. Por favor, extrae manualmente el archivo TAR.GZ e intenta de nuevo." "ERROR"
                exit 1
            }
            
            Log-Action "7-Zip instalado correctamente." "SUCCESS"
        }
        
        # Extraer TAR.GZ con 7-Zip
        $tarFile = Join-Path $env:TEMP "cudnn.tar"
        
        # Primero extraer .gz a .tar
        Start-Process -FilePath $sevenZipPath -ArgumentList "e", "`"$cudnnZipPath`"", "-o`"$env:TEMP`"", "-y" -Wait
        
        # Luego extraer .tar
        Start-Process -FilePath $sevenZipPath -ArgumentList "x", "`"$tarFile`"", "-o`"$tempFolder`"", "-y" -Wait
        
        Log-Action "Archivo TAR.GZ extraído correctamente." "SUCCESS"
    }
    catch {
        Log-Action "Error al extraer archivo TAR.GZ: $_" "ERROR"
        exit 1
    }
}
else {
    Log-Action "Formato de archivo no soportado: $fileExtension. Por favor, proporciona un archivo ZIP o TAR.GZ." "ERROR"
    exit 1
}

# Detectar la versión de CUDA instalada
$cudaVersion = "12.4"
$cudaPath = "${env:ProgramFiles}\NVIDIA GPU Computing Toolkit\CUDA\v$cudaVersion"

if (-not (Test-Path $cudaPath)) {
    # Intentar encontrar cualquier versión de CUDA instalada
    $cudaInstallPath = "${env:ProgramFiles}\NVIDIA GPU Computing Toolkit\CUDA"
    $cudaFolders = Get-ChildItem -Path $cudaInstallPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "v*" }
    
    if ($cudaFolders -and $cudaFolders.Count -gt 0) {
        $cudaPath = $cudaFolders[0].FullName
        $cudaVersion = $cudaFolders[0].Name.Substring(1)
        Log-Action "CUDA $cudaVersion encontrado en: $cudaPath" "INFO"
    }
    else {
        Log-Action "No se encontró ninguna instalación de CUDA. Por favor, instala CUDA primero." "ERROR"
        exit 1
    }
}

# Buscar carpetas bin, include y lib dentro del archivo extraído de cuDNN
$extractedPaths = Get-ChildItem -Path $tempFolder -Recurse -Directory | Where-Object { $_.Name -in @("bin", "include", "lib") -or $_.Name -like "lib*" }

# Encontrar la carpeta raíz que contiene bin, include y lib
$cudnnRoot = $tempFolder
foreach ($folder in (Get-ChildItem -Path $tempFolder -Directory)) {
    $hasAllFolders = $true
    foreach ($requiredFolder in @("bin", "include", "lib")) {
        if (-not (Test-Path (Join-Path $folder.FullName $requiredFolder))) {
            $testLibVariants = Get-ChildItem -Path $folder.FullName -Directory | Where-Object { $_.Name -like "lib*" }
            if ($requiredFolder -eq "lib" -and $testLibVariants) {
                # Encontró una variante de lib (lib64, etc.)
                continue
            }
            
            $hasAllFolders = $false
            break
        }
    }
    
    if ($hasAllFolders) {
        $cudnnRoot = $folder.FullName
        break
    }
}

# Copiar archivos
Log-Action "Copiando archivos cuDNN a la instalación de CUDA $cudaVersion..." "INFO"

# Archivos de bin
$cudnnBinPath = Join-Path $cudnnRoot "bin"
if (Test-Path $cudnnBinPath) {
    $destinationBinPath = Join-Path $cudaPath "bin"
    Get-ChildItem -Path $cudnnBinPath -Filter "*.dll" | ForEach-Object {
        $destFile = Join-Path $destinationBinPath $_.Name
        Copy-Item -Path $_.FullName -Destination $destFile -Force
        Log-Action "Copiado: $($_.Name) a $destinationBinPath" "SUCCESS"
    }
}
else {
    # Buscar en otras ubicaciones
    $altBinPath = Get-ChildItem -Path $tempFolder -Recurse -Filter "*.dll" | Where-Object { $_.Directory.Name -eq "bin" } | Select-Object -First 1 -ExpandProperty Directory
    if ($altBinPath) {
        $destinationBinPath = Join-Path $cudaPath "bin"
        Get-ChildItem -Path $altBinPath -Filter "*.dll" | ForEach-Object {
            $destFile = Join-Path $destinationBinPath $_.Name
            Copy-Item -Path $_.FullName -Destination $destFile -Force
            Log-Action "Copiado: $($_.Name) a $destinationBinPath" "SUCCESS"
        }
    }
    else {
        Log-Action "No se encontraron archivos DLL de cuDNN." "WARNING"
    }
}

# Archivos de include
$cudnnIncludePath = Join-Path $cudnnRoot "include"
if (Test-Path $cudnnIncludePath) {
    $destinationIncludePath = Join-Path $cudaPath "include"
    Get-ChildItem -Path $cudnnIncludePath -Filter "*.h" | ForEach-Object {
        $destFile = Join-Path $destinationIncludePath $_.Name
        Copy-Item -Path $_.FullName -Destination $destFile -Force
        Log-Action "Copiado: $($_.Name) a $destinationIncludePath" "SUCCESS"
    }
}
else {
    # Buscar en otras ubicaciones
    $altIncludePath = Get-ChildItem -Path $tempFolder -Recurse -Filter "cudnn.h" | Select-Object -First 1 -ExpandProperty Directory
    if ($altIncludePath) {
        $destinationIncludePath = Join-Path $cudaPath "include"
        Get-ChildItem -Path $altIncludePath -Filter "*.h" | ForEach-Object {
            $destFile = Join-Path $destinationIncludePath $_.Name
            Copy-Item -Path $_.FullName -Destination $destFile -Force
            Log-Action "Copiado: $($_.Name) a $destinationIncludePath" "SUCCESS"
        }
    }
    else {
        Log-Action "No se encontraron archivos de cabecera (.h) de cuDNN." "WARNING"
    }
}

# Archivos de lib
$cudnnLibPath = Join-Path $cudnnRoot "lib"
if (-not (Test-Path $cudnnLibPath)) {
    # Buscar variantes de la carpeta lib (lib64, etc.)
    $cudnnLibPath = Get-ChildItem -Path $cudnnRoot -Directory | Where-Object { $_.Name -like "lib*" } | Select-Object -First 1 -ExpandProperty FullName
}

if (Test-Path $cudnnLibPath) {
    $destinationLibPath = Join-Path $cudaPath "lib"
    if (-not (Test-Path $destinationLibPath)) {
        $destinationLibPath = Join-Path $cudaPath "lib64"
    }
    
    if (-not (Test-Path $destinationLibPath)) {
        # Crear carpeta lib si no existe
        $destinationLibPath = Join-Path $cudaPath "lib"
        New-Item -Path $destinationLibPath -ItemType Directory -Force | Out-Null
    }
    
    # Comprobar si hay una carpeta x64 en la ruta de lib
    $x64Path = Join-Path $cudnnLibPath "x64"
    if (Test-Path $x64Path) {
        $cudnnLibPath = $x64Path
    }
    
    # Copiar archivos .lib
    Get-ChildItem -Path $cudnnLibPath -Filter "*.lib" | ForEach-Object {
        $destFile = Join-Path $destinationLibPath $_.Name
        Copy-Item -Path $_.FullName -Destination $destFile -Force
        Log-Action "Copiado: $($_.Name) a $destinationLibPath" "SUCCESS"
    }
}
else {
    # Buscar en otras ubicaciones
    $altLibPath = Get-ChildItem -Path $tempFolder -Recurse -Filter "*.lib" | Where-Object { $_.Directory.Name -like "lib*" } | Select-Object -First 1 -ExpandProperty Directory
    if ($altLibPath) {
        $destinationLibPath = Join-Path $cudaPath "lib"
        if (-not (Test-Path $destinationLibPath)) {
            $destinationLibPath = Join-Path $cudaPath "lib64"
        }
        
        if (-not (Test-Path $destinationLibPath)) {
            # Crear carpeta lib si no existe
            $destinationLibPath = Join-Path $cudaPath "lib"
            New-Item -Path $destinationLibPath -ItemType Directory -Force | Out-Null
        }
        
        Get-ChildItem -Path $altLibPath -Filter "*.lib" | ForEach-Object {
            $destFile = Join-Path $destinationLibPath $_.Name
            Copy-Item -Path $_.FullName -Destination $destFile -Force
            Log-Action "Copiado: $($_.Name) a $destinationLibPath" "SUCCESS"
        }
    }
    else {
        Log-Action "No se encontraron archivos de biblioteca (.lib) de cuDNN." "WARNING"
    }
}

# Limpiar carpeta temporal
Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue

Log-Action "Instalación de cuDNN completada." "SUCCESS"
Log-Action "Para verificar la instalación, ejecuta el script verify.py" "INFO"
