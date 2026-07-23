<#
.SYNOPSIS
    Script de desinstalacion de la herramienta de borrado seguro.
.DESCRIPTION
    Elimina la Tarea Programada de Windows y remueve los archivos instalados.
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [string]$InstallDir = "C:\Program Files\HealthCenterCleanup",
    [string]$TaskName = "HealthCenter-SecureCleanup",
    [switch]$RemoveLogs
)

$ErrorActionPreference = "Continue"

Write-Host "Iniciando desinstalacion de HealthCenter Cleanup Tool..." -ForegroundColor Yellow

# 1. Eliminar Tarea Programada
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Eliminando Tarea Programada '$TaskName'..." -ForegroundColor Cyan
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
} else {
    Write-Host "La tarea programada '$TaskName' no existia." -ForegroundColor Gray
}

# 2. Eliminar Directorio de Instalación
if (Test-Path $InstallDir) {
    Write-Host "Removiendo archivos en '$InstallDir'..." -ForegroundColor Cyan
    Remove-Item -Path $InstallDir -Recurse -Force
}

# 3. Eliminar Logs si se especifica
if ($RemoveLogs) {
    $LogDir = "C:\ProgramData\HealthCenterCleanup"
    if (Test-Path $LogDir) {
        Write-Host "Removiendo registros en '$LogDir'..." -ForegroundColor Cyan
        Remove-Item -Path $LogDir -Recurse -Force
    }
}

Write-Host "[OK] Desinstalacion completada exitosamente." -ForegroundColor Green
