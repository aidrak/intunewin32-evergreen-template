# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Intune Win32 application packages in two forms:
- **Evergreen packages** (`packages/`) — Use the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module to automatically download and install the latest version at deployment time. No repackaging needed when vendors release updates.
- **Static packages** (`packages-static/`) — Bundle a pre-downloaded `.exe` installer directly into the `.intunewin` package. No internet access required at install time. Must be rebuilt when the vendor releases a new version.

## Build Commands

### Setup (one-time)
```powershell
# Linux/macOS with PowerShell Core
pwsh
Install-Module -Name SvRooij.ContentPrep.Cmdlet -Scope CurrentUser -Force
```

### Build .intunewin packages
```powershell
# From pwsh shell - output goes into same package folder
New-IntuneWinPackage -SourcePath "packages/GoogleChrome" -SetupFile "GoogleChrome.txt" -DestinationPath "packages/GoogleChrome"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatReaderDC" -SetupFile "AdobeAcrobatReaderDC.txt" -DestinationPath "packages/AdobeAcrobatReaderDC"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatDC" -SetupFile "AdobeAcrobatDC.txt" -DestinationPath "packages/AdobeAcrobatDC"
New-IntuneWinPackage -SourcePath "packages/Microsoft365Apps" -SetupFile "Microsoft365Apps.txt" -DestinationPath "packages/Microsoft365Apps"
```

### Extract package for inspection
```powershell
Unlock-IntuneWinPackage -SourceFile "packages/GoogleChrome/GoogleChrome.intunewin" -DestinationPath "extracted"
```

## Architecture

### Package Structure
Each package in `packages/` follows the same pattern:
- `AppName.txt` - Dummy file for .intunewin naming (required by build tool)
- `Install.ps1` - Downloads latest version via Evergreen and installs silently
- `Uninstall.ps1` - Removes the application
- `Detect.ps1` - Detection script for Intune (exit 0 = installed, exit 1 = not)

### Install Script Pattern
All Install.ps1 scripts follow this flow:
1. Trust PSGallery and install Evergreen module
2. Run `Update-Evergreen` to download app manifests (required for SYSTEM account)
3. Query `Get-EvergreenApp` with filters (architecture, channel, type, language)
4. Download via `Save-EvergreenApp -Path $TempPath`
5. Silent install with `ALLUSERS=1` for VDI/multi-user support
6. Log to `C:\ProgramData\Intune\Logs\{AppName}-Install.log`

### Standard Paths
All scripts use `C:\ProgramData\Intune\` as the base directory:
- **Logs:** `C:\ProgramData\Intune\Logs\` - Installation and MSI logs
- **Downloads:** `C:\ProgramData\Intune\Downloads\{AppName}\` - Temporary installer downloads (cleaned up after install)

### Key Evergreen Commands
```powershell
Find-EvergreenApp -Name "keyword"           # Search available apps
Get-EvergreenApp -Name "AppName"            # Get latest version info
Save-EvergreenApp -Path $TempPath           # Download installer (pipe from Get-EvergreenApp)
Update-Evergreen                            # Download manifests (required for SYSTEM account)
```

## Adding New Packages

1. Create `packages/NewApp/` folder
2. Create `NewApp.txt` (empty dummy file)
3. Create `Install.ps1` using the Evergreen template from BUILD.md
4. Create `Uninstall.ps1` for removal
5. Create `Detect.ps1` returning exit 0 if installed
6. Build with `New-IntuneWinPackage -SourcePath "packages/NewApp" -SetupFile "NewApp.txt" -DestinationPath "packages/NewApp"`

## Static .exe Packages

Static packages live in `packages-static/` and bundle a pre-downloaded installer. No Evergreen dependency, no internet required at install time.

### Package Structure
```
packages-static/AppName/
  SomeInstaller.exe     # The actual installer binary (user drops this in)
  AppName.txt           # Empty dummy file for .intunewin naming
  Install.ps1           # Runs the .exe from $PSScriptRoot
  Uninstall.ps1         # Removes the app (method varies per package)
  Detect.ps1            # Detects installation (method varies per package)
  AppName.intunewin     # Built package output
```

### Bare Conversion (no scripts)

If the user just wants an `.exe` converted to `.intunewin` with no wrapper scripts, use the `.exe` itself as the SetupFile:
```bash
pwsh -Command "New-IntuneWinPackage -SourcePath 'packages-static/AppName' -SetupFile 'AppName.exe' -DestinationPath '/tmp'" && mv /tmp/AppName.intunewin packages-static/AppName/
```
The user configures install/uninstall/detection directly in Intune (e.g., install command: `AppName.exe /S`).

**Note:** `.exe` and `.intunewin` files in `packages-static/` are gitignored (too large for GitHub). Only scripts and docs are tracked. Store/distribute binaries separately.

### Creating a Static Package (with scripts)

When asked to create a static package with scripts, ask the user for:
1. **App name** — used for folder name, logging, and script references
2. **Installer filename** — the .exe already placed in the folder
3. **Silent install arguments** — e.g. `/S`, `/VERYSILENT /NORESTART`, `/quiet /norestart ALLUSERS=1`
4. **Detection method** — path-based (exe path + expected install location) OR registry-based (DisplayName pattern)
5. **Uninstall method** — registry lookup (DisplayName + silent args), hardcoded command, or MSI product code

### Install.ps1 Template
```powershell
#Requires -Version 5.1
[CmdletBinding()]
param()

$AppName = "{AppName}"
$InstallerName = "{InstallerFilename.exe}"
$BasePath = "C:\ProgramData\Intune"
$LogPath = Join-Path -Path $BasePath -ChildPath "Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Install.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    Write-Host $LogMessage
}

try {
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    Write-Log "Starting $AppName installation"

    $InstallerPath = Join-Path -Path $PSScriptRoot -ChildPath $InstallerName
    if (-not (Test-Path $InstallerPath)) {
        throw "Installer not found: $InstallerPath"
    }
    Write-Log "Installer: $InstallerPath"

    Write-Log "Installing..."
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList "{SILENT_ARGS}" -Wait -PassThru -NoNewWindow
    Write-Log "Install exit code: $($Process.ExitCode)"

    Write-Log "Installation complete"
    exit $Process.ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
```

### Detect.ps1 Patterns

**Path-based:**
```powershell
$ExePath = "{INSTALL_PATH}\{executable.exe}"
if (Test-Path -Path $ExePath) {
    $Version = (Get-Item -Path $ExePath).VersionInfo.FileVersion
    Write-Output "{AppName} $Version detected"
    exit 0
}
exit 1
```

**Registry-based:**
```powershell
$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$App = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*{DisplayNamePattern}*" } |
    Select-Object -First 1
if ($App) {
    Write-Output "{AppName} $($App.DisplayVersion) detected"
    exit 0
}
exit 1
```

### Uninstall.ps1 Patterns

**Registry lookup** (find uninstall string from registry):
```powershell
$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$App = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*{DisplayNamePattern}*" } |
    Select-Object -First 1
if ($App) {
    $UninstallCmd = $App.UninstallString
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$UninstallCmd`" {SILENT_UNINSTALL_ARGS}" -Wait -NoNewWindow
}
```

**Hardcoded command** (known uninstall path):
```powershell
$Process = Start-Process -FilePath "{UNINSTALL_EXE_PATH}" -ArgumentList "{SILENT_UNINSTALL_ARGS}" -Wait -PassThru -NoNewWindow
exit $Process.ExitCode
```

**MSI product code** (when .exe installs via MSI):
```powershell
$Process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"{PRODUCT_CODE}`" /quiet /norestart" -Wait -PassThru -NoNewWindow
exit $Process.ExitCode
```

### Build Command
```bash
# Linux/macOS
pwsh -Command "New-IntuneWinPackage -SourcePath 'packages-static/AppName' -SetupFile 'AppName.txt' -DestinationPath '/tmp'" && mv /tmp/AppName.intunewin packages-static/AppName/
```

## Intune Deployment

Install command: `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1`
Uninstall command: `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1`
Install behavior: System

See QUICKSTART.md for full Intune configuration steps.
