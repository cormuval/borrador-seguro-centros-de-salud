<#
.SYNOPSIS
    Script de borrado seguro diario para estaciones de trabajo en Centros de Salud.
.DESCRIPTION
    Este script escanea los perfiles de usuario en C:\Users y realiza un borrado seguro
    utilizando Microsoft Sysinternals SDelete sobre las carpetas:
    - Escritorio (Desktop)
    - Documentos (Documents)
    - Descargas (Downloads)

.NOTES
    Autor: Equipo de TI / Salud
    Requisitos: PowerShell 5.1+, SDelete (Sysinternals) instalado en el mismo directorio.
#>

[CmdletBinding()]
param (
    [int]$OverwritePasses = 1,
    [string]$InstallDir = "C:\Program Files\HealthCenterCleanup",
    [string]$LogFilePath = "C:\ProgramData\HealthCenterCleanup\cleanup.log"
)

# ----------------------------------------------------------------------
# Configuración e Inicialización de Logs
# ----------------------------------------------------------------------
$LogDir = [System.IO.Path]::GetDirectoryName($LogFilePath)
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFilePath -Value $LogEntry -Encoding UTF8
    Write-Host $LogEntry
}

Write-Log "======================================================================"
Write-Log "Iniciando proceso de borrado seguro diario en Centro de Salud..."

# Ubicación de SDelete
$SDeletePath = Join-Path $InstallDir "sdelete.exe"
if (-not (Test-Path -Path $SDeletePath)) {
    # Fallback al directorio actual del script
    $SDeletePath = Join-Path $PSScriptRoot "sdelete.exe"
}

$UseSDelete = $true
if (-not (Test-Path -Path $SDeletePath)) {
    Write-Log "ADVERTENCIA: sdelete.exe no fue encontrado en '$SDeletePath'. Se utilizara Remove-Item como metodo secundario." "WARN"
    $UseSDelete = $false
} else {
    Write-Log "SDelete detectado correctamente en: $SDeletePath"
}

# Aceptar EULA de Sysinternals en Registro del Sistema para evitar bloqueos
try {
    $RegKeyHKCU = "HKCU:\Software\Sysinternals\SDelete"
    if (-not (Test-Path $RegKeyHKCU)) { New-Item -Path $RegKeyHKCU -Force | Out-Null }
    Set-ItemProperty -Path $RegKeyHKCU -Name "EulaAccepted" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # En caso de ejecutarse como SYSTEM
    $RegKeyHKU = "Registry::HKEY_USERS\.DEFAULT\Software\Sysinternals\SDelete"
    if (-not (Test-Path $RegKeyHKU)) { New-Item -Path $RegKeyHKU -Force | Out-Null }
    Set-ItemProperty -Path $RegKeyHKU -Name "EulaAccepted" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
} catch {
    Write-Log "No se pudo actualizar la clave del registro para la EULA de SDelete: $_" "WARN"
}

# Perfiles a ignorar (cuentas de sistema y plantillas)
$ExcludedProfiles = @(
    "Public",
    "Default",
    "Default User",
    "All Users",
    "defaultuser0",
    "WDAGUtilityAccount"
)

# Carpetas a limpiar dentro de cada perfil de usuario
$TargetSubFolders = @(
    "Desktop",
    "Escritorio",
    "Documents",
    "Documentos",
    "Downloads",
    "Descargas"
)

# ----------------------------------------------------------------------
# Procesamiento de Perfiles de Usuario
# ----------------------------------------------------------------------
$UsersRoot = "C:\Users"
if (-not (Test-Path $UsersRoot)) {
    Write-Log "El directorio '$UsersRoot' no existe. Abortando limpieza." "ERROR"
    exit 1
}

$UserDirectories = Get-ChildItem -Path $UsersRoot -Directory -Force | Where-Object {
    $ExcludedProfiles -notcontains $_.Name
}

Write-Log "Perfiles de usuario detectados para limpieza: $($UserDirectories.Count)"

foreach ($UserDir in $UserDirectories) {
    $ProfileName = $UserDir.Name
    Write-Log "Procesando perfil de usuario: '$ProfileName' ($($UserDir.FullName))"

    foreach ($SubFolder in $TargetSubFolders) {
        $FolderPath = Join-Path $UserDir.FullName $SubFolder

        if (Test-Path -Path $FolderPath) {
            # Obtener elementos hijos dentro de la carpeta (sin borrar la carpeta principal)
            $Items = Get-ChildItem -Path $FolderPath -Force -ErrorAction SilentlyContinue

            if ($Items.Count -eq 0) {
                Write-Log "  Carpeta '$SubFolder' esta vacia."
                continue
            }

            Write-Log "  Limpiando '$SubFolder' ($($Items.Count) elementos principales)..."

            foreach ($Item in $Items) {
                $ItemPath = $Item.FullName
                try {
                    if ($UseSDelete) {
                        # sdelete.exe: -p <pasadas>, -s (recursivo), -q (modo silencioso), -accepteula
                        $ProcessParams = @{
                            FilePath     = $SDeletePath
                            ArgumentList = "-p $OverwritePasses -s -q -accepteula `"$ItemPath`""
                            NoNewWindow  = $true
                            Wait         = $true
                            PassThru     = $true
                        }

                        $Proc = Start-Process @ProcessParams
                        if ($Proc.ExitCode -ne 0 -and (Test-Path $ItemPath)) {
                            Write-Log "    SDelete retorno codigo $($Proc.ExitCode) en: $ItemPath. Aplicando Remove-Item fallback..." "WARN"
                            Remove-Item -Path $ItemPath -Recurse -Force -ErrorAction Stop
                        } else {
                            Write-Log "    Borrado seguro exitoso: $ItemPath"
                        }
                    } else {
                        # Fallback a Remove-Item nativo
                        Remove-Item -Path $ItemPath -Recurse -Force -ErrorAction Stop
                        Write-Log "    Borrado (Remove-Item): $ItemPath"
                    }
                } catch {
                    Write-Log "    ERROR al eliminar '$ItemPath': $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

Write-Log "Limpieza finalizada correctamente."
Write-Log "======================================================================"
