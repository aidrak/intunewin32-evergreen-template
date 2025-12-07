# Intune Win32 Evergreen Template

A template repository for deploying Windows applications via Microsoft Intune using the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module.

Based on patterns from [PSPackageFactory](https://github.com/aaronparker/packagefactory) by Aaron Parker.

## Features

- **Evergreen Integration**: Automatically downloads latest application versions
- **Standardized Structure**: Consistent package layout for all applications
- **Enterprise Ready**: Pre-configured for silent installation with update suppression
- **Detection Scripts**: PowerShell-based detection for Intune compliance

## Repository Structure

```
intunewin32-evergreen-template/
├── install/
│   ├── Install.ps1          # Generic installation script
│   └── Install.psm1         # Shared functions module
├── packages/
│   ├── GoogleChrome/
│   │   ├── App.json          # Intune app configuration
│   │   └── Source/
│   │       ├── Install.json      # Installation configuration
│   │       ├── Install.ps1       # Installation script
│   │       ├── Uninstall.ps1     # Uninstallation script
│   │       ├── Detect.ps1        # Detection script
│   │       └── initial_preferences
│   ├── AdobeAcrobatReaderDC/
│   │   └── Source/
│   │       ├── Install.json
│   │       ├── Install.ps1
│   │       └── Detect.ps1
│   └── AdobeAcrobatReaderDCMUIVDI/
│       └── Source/
│           ├── Install.json
│           ├── Install.ps1
│           ├── Detect.ps1
│           └── VDI-enUS.mst      # Optional VDI transform
├── scripts/
│   ├── Get-LatestInstallers.ps1  # Download latest versions
│   └── New-IntuneWin32Package.ps1 # Create .intunewin files
└── output/                       # Generated .intunewin packages
```

## Included Applications

| Application | Description |
|-------------|-------------|
| **Google Chrome Enterprise** | Enterprise MSI with initial preferences |
| **Adobe Acrobat Reader DC** | Standard x64 version with update suppression |
| **Adobe Acrobat Reader DC MUI VDI** | Multi-language VDI-optimized version |

## Prerequisites

1. **PowerShell 5.1** (Windows PowerShell)
2. **Evergreen Module**:
   ```powershell
   Install-Module -Name Evergreen -Force
   ```
3. **Microsoft Win32 Content Prep Tool** (for creating .intunewin packages):
   - Download from [GitHub](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
   - Place `IntuneWinAppUtil.exe` in `scripts/` or `tools/` folder

## Quick Start

### 1. Download Latest Installers

```powershell
# Download all applications
.\scripts\Get-LatestInstallers.ps1

# Download specific application
.\scripts\Get-LatestInstallers.ps1 -AppName GoogleChrome
```

### 2. Create Intune Packages

```powershell
# Package all applications
.\scripts\New-IntuneWin32Package.ps1

# Package specific application
.\scripts\New-IntuneWin32Package.ps1 -AppName GoogleChrome
```

### 3. Upload to Intune

1. Open [Microsoft Intune admin center](https://intune.microsoft.com)
2. Navigate to **Apps** > **All apps** > **Add**
3. Select **Windows app (Win32)**
4. Upload the `.intunewin` file from `output/` folder
5. Configure using values from `App.json`:
   - **Install command**: `powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File .\Install.ps1`
   - **Uninstall command**: See App.json for application-specific command
   - **Detection rules**: Use the `Detect.ps1` script or file-based detection from App.json

## Package Configuration

### App.json

Contains Intune app metadata and configuration:

```json
{
  "Application": {
    "Name": "GoogleChrome",
    "Filter": { "Architecture": "x64", "Channel": "stable" }
  },
  "PackageInformation": {
    "SetupType": "MSI",
    "SetupFile": "googlechromestandaloneenterprise64.msi",
    "Version": "142.0.7444.176"
  },
  "Program": {
    "InstallCommand": "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File .\\Install.ps1",
    "UninstallCommand": "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File .\\Uninstall.ps1"
  },
  "DetectionRule": {
    "Type": "File",
    "Path": "C:\\Program Files\\Google\\Chrome\\Application",
    "FileOrFolder": "chrome.exe",
    "DetectionType": "Version",
    "Operator": "greaterThanOrEqual",
    "Value": "142.0.7444.176"
  }
}
```

### Install.json

Configuration for the installation script:

```json
{
  "PackageInformation": {
    "SetupType": "MSI",
    "SetupFile": "googlechromestandaloneenterprise64.msi",
    "Version": "142.0.7444.176"
  },
  "InstallTasks": {
    "ArgumentList": "/package \"#SetupFile\" ALLUSERS=1 /quiet /log \"#LogPath\\#LogName.log\"",
    "Wait": 10
  },
  "PostInstall": {
    "Remove": ["C:\\Users\\Public\\Desktop\\Google Chrome.lnk"],
    "CopyFile": [
      { "Source": "initial_preferences", "Destination": "C:\\Program Files\\Google\\Chrome\\Application\\initial_preferences" }
    ]
  }
}
```

## Adding New Applications

1. Create a new folder under `packages/` with the application name
2. Create `App.json` with Intune metadata
3. Create `Source/` folder with:
   - `Install.json` - Installation configuration
   - `Install.ps1` - Installation script
   - `Detect.ps1` - Detection script
   - Any additional files (transforms, preferences, etc.)
4. Add the application to `scripts/Get-LatestInstallers.ps1` if using Evergreen

### Evergreen Application Names

Find available applications:

```powershell
Find-EvergreenApp | Select-Object -ExpandProperty Name
```

Get application details:

```powershell
Get-EvergreenApp -Name "GoogleChrome" | Format-List
```

## Logging

Installation logs are written to:
```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\
```

Log files follow the pattern: `{AppName}-Install.log`

## VDI Optimization

The `AdobeAcrobatReaderDCMUIVDI` package includes optimizations for virtual desktop environments:

- Disabled thumbnail preview generation
- Disabled update services
- Reduced mode enforcement
- Multi-language support

For VDI deployments, place your custom `.mst` transform file in the Source folder.

## References

- [Evergreen Documentation](https://eucpilots.com/evergreen-docs/)
- [PSPackageFactory](https://github.com/aaronparker/packagefactory)
- [Intune Win32 App Management](https://docs.microsoft.com/mem/intune/apps/apps-win32-app-management)
- [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)

## License

MIT License - Feel free to use and modify for your organization.
