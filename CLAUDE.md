# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Intune Win32 application packages that use the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module to automatically download and install the latest version of applications at deployment time. No repackaging is needed when vendors release updates.

## Build Commands

### Setup (one-time)
```powershell
# Linux/macOS with PowerShell Core
pwsh
Install-Module -Name SvRooij.ContentPrep.Cmdlet -Scope CurrentUser -Force
```

### Build .intunewin packages
```powershell
# From pwsh shell
New-IntuneWinPackage -SourcePath "packages/GoogleChrome" -SetupFile "GoogleChrome.txt" -DestinationPath "output"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatReaderDC" -SetupFile "AdobeAcrobatReaderDC.txt" -DestinationPath "output"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatDC" -SetupFile "AdobeAcrobatDC.txt" -DestinationPath "output"
```

### Extract package for inspection
```powershell
Unlock-IntuneWinPackage -SourceFile "output/GoogleChrome.intunewin" -DestinationPath "extracted"
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
6. Log to `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\{AppName}-Install.log`

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
6. Build with `New-IntuneWinPackage -SourcePath "packages/NewApp" -SetupFile "NewApp.txt" -DestinationPath "output"`

## Intune Deployment

Install command: `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1`
Uninstall command: `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1`
Install behavior: System

See QUICKSTART.md for full Intune configuration steps.
