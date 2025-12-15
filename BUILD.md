# Building .intunewin Packages

Instructions for rebuilding packages after modifying scripts.

## Setup (One-time)

### Linux/macOS (with PowerShell Core)
```bash
pwsh
Install-Module -Name SvRooij.ContentPrep.Cmdlet -Scope CurrentUser -Force
```

### Windows
Download [IntuneWinAppUtil.exe](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) or use the cross-platform module above.

## Build Packages

Each package folder contains a dummy `.txt` file (e.g., `GoogleChrome.txt`) used to name the output `.intunewin` file. Point the build command at this file.

### Linux/macOS
```powershell
New-IntuneWinPackage -SourcePath "packages/GoogleChrome" -SetupFile "GoogleChrome.txt" -DestinationPath "packages/GoogleChrome"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatReaderDC" -SetupFile "AdobeAcrobatReaderDC.txt" -DestinationPath "packages/AdobeAcrobatReaderDC"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatDC" -SetupFile "AdobeAcrobatDC.txt" -DestinationPath "packages/AdobeAcrobatDC"
New-IntuneWinPackage -SourcePath "packages/Microsoft365Apps" -SetupFile "Microsoft365Apps.txt" -DestinationPath "packages/Microsoft365Apps"
```

### Windows
```powershell
.\IntuneWinAppUtil.exe -c "packages\GoogleChrome" -s "GoogleChrome.txt" -o "packages\GoogleChrome" -q
.\IntuneWinAppUtil.exe -c "packages\AdobeAcrobatReaderDC" -s "AdobeAcrobatReaderDC.txt" -o "packages\AdobeAcrobatReaderDC" -q
.\IntuneWinAppUtil.exe -c "packages\AdobeAcrobatDC" -s "AdobeAcrobatDC.txt" -o "packages\AdobeAcrobatDC" -q
.\IntuneWinAppUtil.exe -c "packages\Microsoft365Apps" -s "Microsoft365Apps.txt" -o "packages\Microsoft365Apps" -q
```

## Extract .intunewin Package (Optional)

To inspect package contents:
```powershell
Unlock-IntuneWinPackage -SourceFile "packages/GoogleChrome/GoogleChrome.intunewin" -DestinationPath "extracted"
```

## Cross-Platform Module Notes

The `SvRooij.ContentPrep.Cmdlet` module:
- Works natively on Linux/macOS with PowerShell Core
- Approximately 2x faster than official Microsoft tool
- Does NOT extract MSI metadata (ProductCode, etc.) - use Windows tool if needed

## Adding New Packages

1. Create folder under `packages/` with app name
2. Create these files:
   - `AppName.txt` - Empty dummy file for naming the .intunewin output
   - `Install.ps1` - Installation script using Evergreen
   - `Uninstall.ps1` - Uninstallation script
   - `Detect.ps1` - Detection script for Intune

3. Use this Evergreen template for `Install.ps1`:
```powershell
$AppName = "YourAppName"
$BasePath = "C:\ProgramData\Intune"
$LogPath = Join-Path -Path $BasePath -ChildPath "Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Install.log"
$TempPath = Join-Path -Path $BasePath -ChildPath "Downloads\$AppName"

# Create directories
if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory -Force | Out-Null }

# Trust PSGallery and install Evergreen
if (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force | Out-Null
    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
}

if (-not (Get-Module -Name Evergreen -ListAvailable)) {
    Install-Module -Name Evergreen -Force -Scope AllUsers
}
Import-Module -Name Evergreen -Force

# Download Evergreen app manifests (required for SYSTEM account)
Update-Evergreen -ErrorAction SilentlyContinue

# Get latest version
$App = Get-EvergreenApp -Name "YourAppName" |
    Where-Object { $_.Architecture -eq "x64" } |
    Select-Object -First 1

# Download using Save-EvergreenApp
$Download = $App | Save-EvergreenApp -Path $TempPath

# Install
Start-Process -FilePath $Download.FullName -ArgumentList "/silent" -Wait

# Cleanup
Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
```

### Standard Paths
All scripts use `C:\ProgramData\Intune\` as the base directory:
- **Logs:** `C:\ProgramData\Intune\Logs\`
- **Downloads:** `C:\ProgramData\Intune\Downloads\{AppName}\` (cleaned up after install)

4. Find available Evergreen apps:
```powershell
Find-EvergreenApp -Name "keyword"
```

5. Build the package:
```powershell
New-IntuneWinPackage -SourcePath "packages/AppName" -SetupFile "AppName.txt" -DestinationPath "packages/AppName"
```
