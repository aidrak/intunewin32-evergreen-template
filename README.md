# Intune Win32 Evergreen Template

Deploy Windows applications via Microsoft Intune that **automatically download the latest version** at install time using the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module.

**No need to repackage when updates are released** - the scripts always pull the latest version from the vendor.

## How It Works

1. Package the PowerShell scripts as a `.intunewin` file (one time)
2. Deploy via Intune
3. At install time, the script:
   - Trusts PSGallery and installs/updates the Evergreen module
   - Queries for the latest version/download URL
   - Downloads directly from the vendor using `Save-EvergreenApp`
   - Installs silently with enterprise/VDI settings
   - Cleans up

## Included Applications

| Package | Description |
|---------|-------------|
| **GoogleChrome** | Chrome Enterprise x64 MSI |
| **AdobeAcrobatReaderDC** | Reader DC x64 MUI with VDI optimizations |
| **AdobeAcrobatDC** | Acrobat DC Pro/Standard x64 (requires licensing) |

## Repository Structure

```
packages/
├── GoogleChrome/
│   ├── Install.ps1      # Downloads & installs latest Chrome
│   ├── Uninstall.ps1    # Removes Chrome
│   └── Detect.ps1       # Detection script for Intune
├── AdobeAcrobatReaderDC/
│   ├── Install.ps1      # Reader with VDI optimizations
│   ├── Uninstall.ps1
│   └── Detect.ps1
└── AdobeAcrobatDC/
    ├── Install.ps1      # Pro/Standard with VDI optimizations
    ├── Uninstall.ps1
    └── Detect.ps1
```

## Quick Start

### 1. Create the .intunewin Package

Download [IntuneWinAppUtil.exe](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) and run:

```cmd
IntuneWinAppUtil.exe -c "packages\GoogleChrome" -s "Install.ps1" -o "output" -q
IntuneWinAppUtil.exe -c "packages\AdobeAcrobatReaderDC" -s "Install.ps1" -o "output" -q
IntuneWinAppUtil.exe -c "packages\AdobeAcrobatDC" -s "Install.ps1" -o "output" -q
```

### 2. Upload to Intune

1. Go to [Intune admin center](https://intune.microsoft.com) > **Apps** > **All apps** > **Add**
2. Select **Windows app (Win32)**
3. Upload the `.intunewin` file

### 3. Configure the App

| Setting | Value |
|---------|-------|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| **Install behavior** | System |
| **Detection rules** | Use custom script > upload `Detect.ps1` |
| **Requirements** | 64-bit, Windows 10 1809+ |

## Requirements

- **Internet access** on endpoints during installation
- **PowerShell 5.1** (built into Windows 10/11)
- Endpoints must be able to reach:
  - `powershellgallery.com` (for Evergreen module)
  - Vendor download servers (Google, Adobe CDN)

## What Each Package Does

### Google Chrome
- Downloads latest stable x64 MSI via Evergreen
- Uses `Save-EvergreenApp` for reliable downloads
- Silent install with `ALLUSERS=1`
- Removes desktop shortcut

### Adobe Acrobat Reader DC
- Downloads latest x64 MUI version (with English fallback)
- Installs with `ALLUSERS=1` for VDI/multi-user environments
- Disables browser integration and Chrome extension
- Disables auto-updates (AdobeARMservice)
- Removes scheduled update tasks
- Suppresses upsell/in-product messages
- Disables thumbnail preview generation (reduces IOPS)
- Removes desktop shortcuts

### Adobe Acrobat DC (Pro/Standard)
- Downloads latest x64 version via Evergreen
- Same VDI/enterprise optimizations as Reader
- **Requires valid Adobe licensing** (volume license, named user, or subscription)

## Adding New Applications

1. Create a folder under `packages/`
2. Create `Install.ps1` using this template:

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

3. Find available apps: `Find-EvergreenApp -Name "keyword"`

## Logging

Install logs are written to:
```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\{AppName}-Install.log
```

## References

- [Evergreen Documentation](https://stealthpuppy.com/evergreen/)
- [Evergreen GitHub](https://github.com/aaronparker/evergreen)
- [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
- [Intune Win32 App Management](https://docs.microsoft.com/mem/intune/apps/apps-win32-app-management)

## License

MIT
