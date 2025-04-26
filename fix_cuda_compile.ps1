# Script para corregir problemas comunes de compilación CUDA
# Agregar #include <cstddef> a archivos .cu

param (
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$HeaderToAdd = "#include <cstddef>"
)

# Verificar que se está ejecutando como administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Se recomienda ejecutar este script como administrador."
}

# Función para registrar acciones
function Log-Action {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Type] $Message"
    
    switch ($Type) {
        "INFO" { Write-Host $logMessage -ForegroundColor Gray }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage }
    }
}

# Verificar que el archivo existe
if (-not (Test-Path $FilePath)) {
    Log-Action "El archivo no existe: $FilePath" "ERROR"
    exit 1
}

# Verificar que el archivo es de tipo .cu o .cuh
$extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
if ($extension -notin @(".cu", ".cuh")) {
    Log-Action "Advertencia: El archivo $FilePath no parece ser un archivo CUDA ($extension). ¿Deseas continuar de todos modos?" "WARNING"
    $continue = Read-Host "Continuar (S/N)?"
    if ($continue -ne "S") {
        Log-Action "Operación cancelada por el usuario." "INFO"
        exit 0
    }
}

# Leer contenido del archivo
try {
    $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    Log-Action "Archivo leído correctamente: $FilePath" "SUCCESS"
}
catch {
    Log-Action "Error al leer el archivo: $_" "ERROR"
    exit 1
}

# Verificar si ya tiene la inclusión
if ($content -like "*$HeaderToAdd*") {
    Log-Action "El archivo ya contiene la inclusión '$HeaderToAdd'" "INFO"
    exit 0
}

# Agregar la inclusión al inicio del archivo
try {
    $newContent = "$HeaderToAdd`n$content"
    Set-Content -Path $FilePath -Value $newContent -ErrorAction Stop
    Log-Action "Se ha añadido '$HeaderToAdd' al inicio de $FilePath" "SUCCESS"
}
catch {
    Log-Action "Error al modificar el archivo: $_" "ERROR"
    exit 1
}

Log-Action "Operación completada. El archivo ha sido modificado correctamente." "SUCCESS"
Log-Action "Este cambio debería resolver errores relacionados con el tipo 'size_t'" "INFO"

# Ofrecer corregir más archivos
$fixMore = Read-Host "¿Deseas corregir otro archivo? (S/N)"
if ($fixMore -eq "S") {
    $newFile = Read-Host "Ingresa la ruta al siguiente archivo"
    if ($newFile) {
        Log-Action "Procesando archivo adicional: $newFile" "INFO"
        & $PSCommandPath -FilePath $newFile -HeaderToAdd $HeaderToAdd
    }
}
