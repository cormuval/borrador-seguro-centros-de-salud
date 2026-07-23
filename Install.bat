@echo off
:: ============================================================================
:: HealthCenter Cleanup Tool - Instalador por Archivo de Lote (.bat)
:: Eleva permisos a Administrador y ejecuta Install.ps1
:: ============================================================================

title Instalador de Borrado Seguro - Centros de Salud

:: Verificar permisos de Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ============================================================================
    echo  ERROR: Este script requiere Permisos de Administrador.
    echo  Por favor haga clic derecho sobre 'Install.bat' y seleccione:
    echo  "Ejecutar como administrador".
    echo ============================================================================
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo  Iniciando instalacion de Borrado Seguro para Centros de Salud...
echo ============================================================================
echo.

:: Ejecutar Install.ps1 con PowerShell sin restricciones de política de ejecución
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"

if %errorLevel% equ 0 (
    echo.
    echo ============================================================================
    echo  [OK] PROCESO FINALIZADO EXITOSAMENTE.
    echo ============================================================================
) else (
    echo.
    echo ============================================================================
    echo  [ERROR] Ocurrio un problema durante la instalacion. Revise el registro.
    echo ============================================================================
)

echo.
pause
