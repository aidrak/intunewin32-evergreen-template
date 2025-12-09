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
New-IntuneWinPackage -SourcePath "packages/GoogleChrome" -SetupFile "GoogleChrome.txt" -DestinationPath "output"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatReaderDC" -SetupFile "AdobeAcrobatReaderDC.txt" -DestinationPath "output"
New-IntuneWinPackage -SourcePath "packages/AdobeAcrobatDC" -SetupFile "AdobeAcrobatDC.txt" -DestinationPath "output"
```

### Windows
```powershell
.\IntuneWinAppUtil.exe -c "packages\GoogleChrome" -s "GoogleChrome.txt" -o "output" -q
.\IntuneWinAppUtil.exe -c "packages\AdobeAcrobatReaderDC" -s "AdobeAcrobatReaderDC.txt" -o "output" -q
.\IntuneWinAppUtil.exe -c "packages\AdobeAcrobatDC" -s "AdobeAcrobatDC.txt" -o "output" -q
```

## Extract .intunewin Package (Optional)

To inspect package contents:
```powershell
Unlock-IntuneWinPackage -SourceFile "output/GoogleChrome.intunewin" -DestinationPath "extracted"
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
# Trust PSGallery and install/update Evergreen
if (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force | Out-Null
    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
}

if (-not (Get-Module -Name Evergreen -ListAvailable)) {
    Install-Module -Name Evergreen -Force -Scope AllUsers
}
Import-Module -Name Evergreen -Force
Update-Module -Name Evergreen -Force -ErrorAction SilentlyContinue

# Get latest version
$App = Get-EvergreenApp -Name "YourAppName" |
    Where-Object { $_.Architecture -eq "x64" } |
    Select-Object -First 1

# Download using Save-EvergreenApp
$Download = $App | Save-EvergreenApp -Path $env:TEMP

# Install
Start-Process -FilePath $Download.FullName -ArgumentList "/silent" -Wait
```

4. Find available Evergreen apps:
```powershell
Find-EvergreenApp -Name "keyword"
```

5. Build the package:
```powershell
New-IntuneWinPackage -SourcePath "packages/AppName" -SetupFile "AppName.txt" -DestinationPath "output"
```
