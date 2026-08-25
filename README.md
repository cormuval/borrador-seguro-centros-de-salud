# Script de Borrado Seguro Automatizado para Centros de Salud (Windows 10/11)

Solución automatizada de borrado seguro diseñada para estaciones de trabajo en **Centros de Salud** (hospitales, CESFAM, clínicas). Se encarga de limpiar diariamente las carpetas de usuario (**Escritorio**, **Documentos** y **Descargas**) utilizando el estándar de sobrescritura de bajo nivel de **Microsoft Sysinternals SDelete**, previniendo la fuga o exposición accidental de datos clínicos y confidenciales.

---

## 🎯 Características Principales

* **Sobrescritura de Bajo Nivel (DoD Standard)**: Utiliza `SDelete` para sobrescribir físicamente los bloques de memoria en disco, impidiendo la recuperación de archivos borrados con herramientas forenses.
* **Integración Nativa con Programador de Tareas**: La tarea se programa automáticamente para ejecutarse con cuenta `SYSTEM` (máximos privilegios) diariamente.
* **Multiusuario**: Escanea y limpia automáticamente las carpetas de todos los perfiles de usuario locales presentes en `C:\Users`.
* **Registro de Auditoría (Logs)**: Genera registros detallados con fecha y hora de cada proceso de limpieza en `C:\ProgramData\HealthCenterCleanup\cleanup.log`.
* **Sin Interrupción al Usuario**: La ejecución es 100% silenciosa en segundo plano (`Hidden`) sin ventanas ni alertas visuales.

---

## 🚀 Método 1: Instalación Rápida por Línea de Comandos (En Línea / Recomendado)

Para desplegar en un equipo conectado a internet o red local, el técnico de TI solo debe abrir **PowerShell como Administrador** y ejecutar este **único comando**:

```powershell
iwr -useb https://raw.githubusercontent.com/cormuval/borrador-seguro-centros-de-salud/main/Install.ps1 | iex
```

> **¿Qué hace este comando?**
> 1. Descarga e instala la herramienta en `C:\Program Files\HealthCenterCleanup`.
> 2. Descarga `sdelete.exe` desde los servidores oficiales de Microsoft.
> 3. Acepta silenciosamente la EULA de Sysinternals en el registro del sistema.
> 4. Registra la Tarea Programada `HealthCenter-SecureCleanup` para ejecutarse todos los días a las **19:00 hrs** bajo la cuenta `SYSTEM`.

---

## 📦 Método 2: Instalación Offline (USB o Carpeta Compartida de Red)

Para centros o estaciones con restricciones de internet:

1. Descarga este repositorio como archivo `.zip` y descomprímelo en un Pendrive USB.
2. Descarga la herramienta oficial `sdelete.exe` de Microsoft Sysinternals y colócala en la misma carpeta.
3. Inserta el USB en el equipo objetivo.
4. Haz clic derecho sobre **`Install.bat`** y selecciona **"Ejecutar como administrador"**.

---

## 🔍 Verificación y Logs de Auditoría

### 1. Verificar la Tarea Programada en Windows
Puedes comprobar la tarea instalada ejecutando en PowerShell:
```powershell
Get-ScheduledTask -TaskName "HealthCenter-SecureCleanup"
```

### 2. Revisar los Registros (Logs)
Los registros de cada borrado diario se almacenan en:
* **Log de Limpieza**: `C:\ProgramData\HealthCenterCleanup\cleanup.log`
* **Log de Instalación**: `C:\ProgramData\HealthCenterCleanup\install.log`

Para visualizar el último registro en tiempo real:
```powershell
Get-Content -Path "C:\ProgramData\HealthCenterCleanup\cleanup.log" -Tail 20
```

---

## ⚙️ Personalización (Opciones Avanzadas)

Si deseas cambiar la hora de ejecución (por ejemplo, a las **18:00 hrs**):
```powershell
.\Install.ps1 -ScheduleTime "18:00"
```

Si deseas aumentar las pasadas de sobrescritura en `Clean-HealthCenterPC.ps1`:
* Por defecto se realiza **1 pasada** (recomendado para equilibrio entre velocidad y seguridad en discos SSD/HDD).
* Se puede configurar a **3 pasadas** pasando el parámetro `-OverwritePasses 3`.

---

## 🗑️ Desinstalación

Para retirar la herramienta y eliminar la tarea programada:

Abre PowerShell como Administrador y ejecuta:
```powershell
.\Uninstall.ps1 -RemoveLogs
```
O de forma remota:
```powershell
iwr -useb https://raw.githubusercontent.com/cormuval/borrador-seguro-centros-de-salud/main/Uninstall.ps1 | iex
```

---

## 📄 Estructura del Repositorio

```text
├── Clean-HealthCenterPC.ps1   # Script principal de borrado seguro
├── Install.ps1                # Script instalador y configurador del Programador de Tareas
├── Install.bat                # Wrapper batch para instalacion por doble clic (USB)
├── Uninstall.ps1              # Script de desinstalacion
└── README.md                  # Documentacion oficial para el equipo de TI
```
