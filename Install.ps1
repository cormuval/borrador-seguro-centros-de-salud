<#
.SYNOPSIS
    Script de instalacion y automatizacion para la limpieza segura en centros de salud.
.DESCRIPTION
    Instala el script de borrado seguro, descargas sdelete.exe y registra una Tarea
    Programada en Windows para ejecucion diaria con permisos de SYSTEM.
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [string]$InstallDir = "C:\Program Files\HealthCenterCleanup",
    [string]$LogDir = "C:\ProgramData\HealthCenterCleanup",
    [string]$ScheduleTime = "19:00",
    [string]$GitHubRepoUrl = "https://raw.githubusercontent.com/cormuval/borrador-seguro-centros-de-salud/main"
)

$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------------
# Configuración e Inicialización de Logs
# ----------------------------------------------------------------------
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$InstallLogPath = Join-Path $LogDir "install.log"

function Write-InstallLog {
    param ([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $InstallLogPath -Value $LogEntry -Encoding UTF8
    Write-Host $LogEntry
}

Write-InstallLog "======================================================================"
Write-InstallLog "Iniciando instalacion de HealthCenter Cleanup Tool..."

# ----------------------------------------------------------------------
# 1. Crear Directorio de Instalación
# ----------------------------------------------------------------------
if (-not (Test-Path -Path $InstallDir)) {
    Write-InstallLog "Creando directorio de instalacion: $InstallDir"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# ----------------------------------------------------------------------
# 2. Descargar o Copiar SDelete y Script Principal
# ----------------------------------------------------------------------
$SDeleteDest = Join-Path $InstallDir "sdelete.exe"
$ScriptDest = Join-Path $InstallDir "Clean-HealthCenterPC.ps1"

# Intentar copiar desde directorio local si existe (para instalacion offline por USB)
$LocalScript = Join-Path $PSScriptRoot "Clean-HealthCenterPC.ps1"
$LocalSDelete = Join-Path $PSScriptRoot "sdelete.exe"

if (Test-Path $LocalScript) {
    Write-InstallLog "Copiando Clean-HealthCenterPC.ps1 desde origen local..."
    Copy-Item -Path $LocalScript -Destination $ScriptDest -Force
} else {
    Write-InstallLog "Descargando Clean-HealthCenterPC.ps1 desde GitHub ($GitHubRepoUrl)..."
    $ScriptUrl = "$GitHubRepoUrl/Clean-HealthCenterPC.ps1"
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptDest -UseBasicParsing
}

if (Test-Path $LocalSDelete) {
    Write-InstallLog "Copiando sdelete.exe desde origen local..."
    Copy-Item -Path $LocalSDelete -Destination $SDeleteDest -Force
} else {
    Write-InstallLog "Descargando sdelete.exe desde Microsoft Sysinternals..."
    try {
        $SDeleteUrl = "https://live.sysinternals.com/sdelete.exe"
        Invoke-WebRequest -Uri $SDeleteUrl -OutFile $SDeleteDest -UseBasicParsing
    } catch {
        Write-InstallLog "No se pudo descargar de Sysinternals Live. Intentando desde fallback GitHub..." "WARN"
        $SDeleteFallbackUrl = "$GitHubRepoUrl/sdelete.exe"
        Invoke-WebRequest -Uri $SDeleteFallbackUrl -OutFile $SDeleteDest -UseBasicParsing
    }
}

# ----------------------------------------------------------------------
# 3. Configurar EULA de SDelete en el Registro de Windows
# ----------------------------------------------------------------------
Write-InstallLog "Aceptando EULA de Sysinternals SDelete en Registro..."
$RegKeys = @(
    "HKCU:\Software\Sysinternals\SDelete",
    "Registry::HKEY_USERS\.DEFAULT\Software\Sysinternals\SDelete"
)

foreach ($Key in $RegKeys) {
    try {
        if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }
        Set-ItemProperty -Path $Key -Name "EulaAccepted" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {
        Write-InstallLog "Advertencia al registrar EULA en ${Key}: $_" "WARN"
    }
}

# ----------------------------------------------------------------------
# 4. Registrar Tarea Programada en Windows (Task Scheduler)
# ----------------------------------------------------------------------
$TaskName = "HealthCenter-SecureCleanup"
Write-InstallLog "Registrando Tarea Programada: '$TaskName'..."

# Eliminar tarea previa si existe
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-InstallLog "Eliminando version anterior de la tarea programada..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptDest`""

$Trigger = New-ScheduledTaskTrigger -Daily -At $ScheduleTime

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

$Principal = New-ScheduledTaskPrincipal `
    -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Description "Borrado seguro diario de carpetas de usuario (Escritorio, Documentos, Descargas) para Centros de Salud." `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Principal $Principal | Out-Null

Write-InstallLog "Tarea programada registrada exitosamente para ejecutarse a las $ScheduleTime con privilegios de SYSTEM."
Write-InstallLog "Instalacion completada con exito."
Write-InstallLog "======================================================================"

Write-Host "`n[OK] Instalacion completada exitosamente." -ForegroundColor Green
Write-Host "La tarea programada '$TaskName' esta lista para ejecutarse todos los dias a las $ScheduleTime." -ForegroundColor Cyan
