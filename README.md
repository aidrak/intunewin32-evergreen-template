# Intune Win32 Evergreen Template

Deploy Windows applications via Microsoft Intune that **automatically download the latest version** at install time using the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module.

**No need to repackage when updates are released** - the scripts always pull the latest version from the vendor.

## How It Works

1. Package the PowerShell scripts as a `.intunewin` file (one time)
2. Deploy via Intune
3. At install time, the script:
   - Trusts PSGallery and installs the Evergreen module
   - Downloads Evergreen app manifests via `Update-Evergreen`
   - Queries for the latest version/download URL
   - Downloads directly from the vendor using `Save-EvergreenApp`
   - Installs silently with enterprise settings
   - Cleans up

## Included Applications

| Package | Description |
|---------|-------------|
| **GoogleChrome** | Chrome Enterprise x64 MSI |
| **AdobeAcrobatReaderDC** | Reader DC x64 MUI |
| **AdobeAcrobatDC** | Acrobat DC Pro/Standard x64 (requires licensing) |

## Repository Structure

```
packages/
├── GoogleChrome/
│   ├── GoogleChrome.txt  # Dummy file for .intunewin naming
│   ├── Install.ps1       # Downloads & installs latest Chrome
│   ├── Uninstall.ps1     # Removes Chrome
│   └── Detect.ps1        # Detection script for Intune
├── AdobeAcrobatReaderDC/
│   ├── AdobeAcrobatReaderDC.txt
│   ├── Install.ps1
│   ├── Uninstall.ps1
│   └── Detect.ps1
└── AdobeAcrobatDC/
    ├── AdobeAcrobatDC.txt
    ├── Install.ps1
    ├── Uninstall.ps1
    └── Detect.ps1
```

## Quick Start

See [QUICKSTART.md](QUICKSTART.md) for step-by-step Intune deployment instructions.

See [BUILD.md](BUILD.md) for building `.intunewin` packages.

## Requirements

- **Internet access** on endpoints during installation
- **PowerShell 5.1** (built into Windows 10/11)
- Endpoints must be able to reach:
  - `powershellgallery.com` (for Evergreen module)
  - Vendor download servers (Google, Adobe CDN)

## What Each Package Does

### Google Chrome
- Downloads latest stable x64 MSI via Evergreen
- Silent install with `ALLUSERS=1`
- Creates desktop shortcut on public desktop

### Adobe Acrobat Reader DC
- Downloads latest x64 MUI version (with English fallback)
- Installs with `ALLUSERS=1` for multi-user environments

### Adobe Acrobat DC (Pro/Standard)
- Downloads latest x64 version via Evergreen
- Extracts ZIP and runs setup.exe
- Installs with `ALLUSERS=1` for multi-user environments
- **Requires valid Adobe licensing** (volume license, named user, or subscription)

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
