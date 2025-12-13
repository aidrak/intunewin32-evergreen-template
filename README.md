# Intune Win32 Evergreen Template

Deploy Windows applications via Microsoft Intune that **automatically download the latest version** at install time using the [Evergreen](https://github.com/aaronparker/evergreen) PowerShell module.

**No need to repackage when updates are released** - the scripts always pull the latest version from the vendor.

## How It Works

1. Package the PowerShell scripts as a `.intunewin` file (one time)
2. Deploy via Intune
3. At install time, the script:
   - Installs the Evergreen module from PSGallery
   - Queries for the latest version/download URL
   - Downloads directly from the vendor
   - Installs silently with enterprise settings
   - Cleans up

## Included Packages

| Package | Description |
|---------|-------------|
| [GoogleChrome](packages/GoogleChrome/) | Chrome Enterprise x64 MSI |
| [AdobeAcrobatReaderDC](packages/AdobeAcrobatReaderDC/) | Reader DC x64 MUI |
| [AdobeAcrobatDC](packages/AdobeAcrobatDC/) | Acrobat DC Pro/Standard x64 (requires licensing) |
| [Microsoft365Apps](packages/Microsoft365Apps/) | Microsoft 365 Apps via ODT (parameterized) |

See each package's README for Intune configuration details.

## Repository Structure

```
packages/
├── GoogleChrome/
│   ├── GoogleChrome.intunewin
│   ├── Install.ps1
│   ├── Uninstall.ps1
│   └── README.md
├── AdobeAcrobatReaderDC/
│   ├── AdobeAcrobatReaderDC.intunewin
│   ├── Install.ps1
│   ├── Uninstall.ps1
│   └── README.md
├── AdobeAcrobatDC/
│   ├── AdobeAcrobatDC.intunewin
│   ├── Install.ps1
│   ├── Uninstall.ps1
│   └── README.md
└── Microsoft365Apps/
    ├── Microsoft365Apps.intunewin
    ├── Install.ps1
    ├── Uninstall.ps1
    └── README.md
```

## Quick Start

1. Download the `.intunewin` file from the package folder
2. Upload to Intune as a Win32 app
3. Configure using the settings in the package's README

See [BUILD.md](BUILD.md) for rebuilding packages after script modifications.

## Requirements

- **Internet access** on endpoints during installation
- **PowerShell 5.1** (built into Windows 10/11)
- Endpoints must reach: `powershellgallery.com` and vendor download servers

## Logging

All packages log to: `C:\ProgramData\Intune\Logs\{AppName}-Install.log`

## References

- [Evergreen Documentation](https://stealthpuppy.com/evergreen/)
- [Evergreen GitHub](https://github.com/aaronparker/evergreen)
- [Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)

## License

MIT
