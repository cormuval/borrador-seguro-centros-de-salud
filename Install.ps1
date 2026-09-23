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
# Verificacion de privilegios
# La directiva '#Requires -RunAsAdministrator' solo se evalua cuando el script se
# ejecuta como archivo .ps1; con 'iwr | iex' se ignora, por lo que se valida aqui.
# ----------------------------------------------------------------------
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Este instalador requiere PowerShell ejecutado como Administrador. Cierre esta ventana y abra PowerShell con 'Ejecutar como administrador'."
}

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

function Test-EsEjecutableValido {
    # Verifica la firma 'MZ' de un ejecutable PE. Protege contra proxies o portales
    # cautivos que responden HTTP 200 con una pagina HTML en lugar del binario.
    param ([string]$Path)
    if (-not (Test-Path -Path $Path)) { return $false }
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $Bytes = Get-Content -Path $Path -AsByteStream -TotalCount 2 -ErrorAction Stop
        } else {
            $Bytes = Get-Content -Path $Path -Encoding Byte -TotalCount 2 -ErrorAction Stop
        }
        return ($Bytes.Count -eq 2 -and $Bytes[0] -eq 0x4D -and $Bytes[1] -eq 0x5A)
    } catch {
        return $false
    }
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

# Intentar copiar desde directorio local si existe (para instalacion offline por USB).
# $PSScriptRoot esta vacio cuando el script se ejecuta via 'iwr | iex' (no hay archivo
# de origen), por lo que se resuelve con fallback y se omite el modo local si no aplica.
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot -and $PSCommandPath) { $ScriptRoot = Split-Path -Parent $PSCommandPath }

$LocalScript = $null
$LocalSDelete = $null
if ($ScriptRoot) {
    $LocalScript = Join-Path $ScriptRoot "Clean-HealthCenterPC.ps1"
    $LocalSDelete = Join-Path $ScriptRoot "sdelete.exe"
} else {
    Write-InstallLog "Ejecucion remota detectada (sin directorio local). Se descargaran los archivos desde GitHub."
}

if ($LocalScript -and (Test-Path $LocalScript)) {
    Write-InstallLog "Copiando Clean-HealthCenterPC.ps1 desde origen local..."
    Copy-Item -Path $LocalScript -Destination $ScriptDest -Force
} else {
    Write-InstallLog "Descargando Clean-HealthCenterPC.ps1 desde GitHub ($GitHubRepoUrl)..."
    $ScriptUrl = "$GitHubRepoUrl/Clean-HealthCenterPC.ps1"
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $ScriptDest -UseBasicParsing
}

# SDelete NO se redistribuye en este repositorio: la licencia de Sysinternals prohibe
# expresamente publicar el software para que terceros lo copien. Se obtiene siempre
# desde un origen oficial de Microsoft o desde el medio local (instalacion por USB).
$SDeleteObtenido = $false

if ($LocalSDelete -and (Test-Path $LocalSDelete)) {
    Write-InstallLog "Copiando sdelete.exe desde origen local..."
    Copy-Item -Path $LocalSDelete -Destination $SDeleteDest -Force
    $SDeleteObtenido = Test-EsEjecutableValido -Path $SDeleteDest
    if (-not $SDeleteObtenido) {
        Write-InstallLog "El sdelete.exe del origen local no es un ejecutable valido." "WARN"
    }
}

# Origen oficial 1: Sysinternals Live (binario directo).
if (-not $SDeleteObtenido) {
    try {
        Write-InstallLog "Descargando sdelete.exe desde Sysinternals Live..."
        Invoke-WebRequest -Uri "https://live.sysinternals.com/sdelete.exe" -OutFile $SDeleteDest -UseBasicParsing
        $SDeleteObtenido = Test-EsEjecutableValido -Path $SDeleteDest
        if (-not $SDeleteObtenido) {
            Write-InstallLog "La respuesta de Sysinternals Live no es un ejecutable valido (posible proxy o portal cautivo)." "WARN"
            Remove-Item -Path $SDeleteDest -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-InstallLog "No se pudo descargar de Sysinternals Live: $($_.Exception.Message)" "WARN"
        Remove-Item -Path $SDeleteDest -Force -ErrorAction SilentlyContinue
    }
}

# Origen oficial 2: paquete SDelete.zip. Es un host distinto a live.sysinternals.com,
# que suele estar bloqueado en redes institucionales, por lo que sirve de alternativa.
if (-not $SDeleteObtenido) {
    $TempZip = Join-Path $env:TEMP "SDelete.zip"
    $TempDir = Join-Path $env:TEMP "SDelete_install"
    try {
        Write-InstallLog "Intentando descarga alternativa desde download.sysinternals.com..."
        Invoke-WebRequest -Uri "https://download.sysinternals.com/files/SDelete.zip" -OutFile $TempZip -UseBasicParsing

        if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
        Expand-Archive -Path $TempZip -DestinationPath $TempDir -Force

        $SDeleteExtraido = Join-Path $TempDir "sdelete.exe"
        if (-not (Test-Path $SDeleteExtraido)) {
            throw "El paquete descargado no contiene sdelete.exe."
        }

        Copy-Item -Path $SDeleteExtraido -Destination $SDeleteDest -Force
        $SDeleteObtenido = Test-EsEjecutableValido -Path $SDeleteDest
        if ($SDeleteObtenido) {
            Write-InstallLog "sdelete.exe extraido correctamente del paquete oficial de Sysinternals."
        } else {
            Write-InstallLog "El sdelete.exe extraido del paquete no es un ejecutable valido." "WARN"
            Remove-Item -Path $SDeleteDest -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-InstallLog "Tampoco se pudo obtener SDelete desde download.sysinternals.com: $($_.Exception.Message)" "WARN"
    } finally {
        Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Sin SDelete la instalacion continua: la limpieza diaria usara el metodo secundario.
if (-not $SDeleteObtenido) {
    Write-InstallLog "No fue posible instalar SDelete desde ningun origen. La limpieza diaria se ejecutara con el metodo secundario (Remove-Item), que elimina los archivos pero NO sobrescribe los datos en disco." "WARN"
    Write-InstallLog "Para habilitar la sobrescritura segura, copie sdelete.exe manualmente en '$InstallDir'." "WARN"
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
