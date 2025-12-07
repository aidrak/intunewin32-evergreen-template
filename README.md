# Intune Win32 Evergreen Template

Deploy Windows applications via Microsoft Intune that **automatically download the latest version** at install time using the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module.

**No need to repackage when updates are released** - the scripts always pull the latest version from the vendor.

## How It Works

1. Package the PowerShell scripts as a `.intunewin` file (one time)
2. Deploy via Intune
3. At install time, the script:
   - Installs the Evergreen module
   - Queries for the latest version/download URL
   - Downloads directly from the vendor
   - Installs silently with enterprise settings
   - Cleans up

## Included Applications

| Package | Description |
|---------|-------------|
| **GoogleChrome** | Chrome Enterprise x64 MSI |
| **AdobeAcrobatReaderDC** | Reader DC x64 English with update suppression |
| **AdobeAcrobatReaderDCMUIVDI** | Reader DC x64 Multi-language with VDI optimizations |

## Repository Structure

```
packages/
├── GoogleChrome/
│   ├── Install.ps1      # Downloads & installs latest Chrome
│   ├── Uninstall.ps1    # Removes Chrome
│   └── Detect.ps1       # Detection script for Intune
├── AdobeAcrobatReaderDC/
│   ├── Install.ps1
│   ├── Uninstall.ps1
│   └── Detect.ps1
└── AdobeAcrobatReaderDCMUIVDI/
    ├── Install.ps1      # Includes VDI optimizations
    ├── Uninstall.ps1
    └── Detect.ps1
```

## Quick Start

### 1. Create the .intunewin Package

Download [IntuneWinAppUtil.exe](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) and run:

```cmd
IntuneWinAppUtil.exe -c "packages\GoogleChrome" -s "Install.ps1" -o "output" -q
```

### 2. Upload to Intune

1. Go to [Intune admin center](https://intune.microsoft.com) → **Apps** → **All apps** → **Add**
2. Select **Windows app (Win32)**
3. Upload the `.intunewin` file

### 3. Configure the App

| Setting | Value |
|---------|-------|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| **Install behavior** | System |
| **Detection rules** | Use custom script → upload `Detect.ps1` |
| **Requirements** | 64-bit, Windows 10 1809+ |

## Requirements

- **Internet access** on endpoints during installation
- **PowerShell 5.1** (built into Windows 10/11)
- Endpoints must be able to reach:
  - `powershellgallery.com` (for Evergreen module)
  - Vendor download servers (Google, Adobe CDN)

## What Each Package Does

### Google Chrome
- Downloads latest stable x64 MSI
- Silent install with `ALLUSERS=1`
- Removes desktop shortcut

### Adobe Acrobat Reader DC
- Downloads latest x64 English version
- Disables browser integration
- Disables Chrome extension
- Disables auto-updates (AdobeARMservice)
- Removes scheduled update tasks
- Suppresses upsell messages
- Removes desktop shortcuts

### Adobe Acrobat Reader DC MUI VDI
Same as above, plus:
- Multi-language support
- Disabled thumbnail preview (reduces IOPS)
- Additional ARM registry tweaks for golden images

## Adding New Applications

1. Create a folder under `packages/`
2. Create `Install.ps1` using this template:

```powershell
# Install/Import Evergreen
if (-not (Get-Module -Name Evergreen -ListAvailable)) {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Install-Module -Name Evergreen -Force -Scope AllUsers
}
Import-Module -Name Evergreen -Force

# Get latest version
$App = Get-EvergreenApp -Name "YourAppName" |
    Where-Object { $_.Architecture -eq "x64" } |
    Select-Object -First 1

# Download
Invoke-WebRequest -Uri $App.URI -OutFile "installer.exe" -UseBasicParsing

# Install
Start-Process -FilePath "installer.exe" -ArgumentList "/silent" -Wait
```

3. Find available apps: `Get-EvergreenApp | Select-Object -ExpandProperty Name`

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
