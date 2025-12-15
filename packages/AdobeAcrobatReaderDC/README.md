# Adobe Acrobat Reader DC Package

Deploys Adobe Acrobat Reader DC x64 using the Evergreen module to always install the latest version.

## Features

- Downloads latest x64 MUI (multi-language) version from Adobe
- Falls back to English if MUI unavailable
- Silent install with `ALLUSERS=1` for multi-user environments
- Stops running Adobe processes before install

---

## Intune Configuration

### Program

| Setting | Value |
|---------|-------|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| **Install behavior** | System |

### Detection Rule

| Setting | Value |
|---------|-------|
| **Rule type** | File |
| **Path** | `C:\Program Files\Adobe\Acrobat Reader DC\Reader` |
| **File** | `AcroRd64.exe` |
| **Detection method** | File or folder exists |

### Requirements

| Setting | Value |
|---------|-------|
| **Operating system architecture** | 64-bit |
| **Minimum operating system** | Windows 10 1809 |

---

## Notes

- **Logs**: `C:\ProgramData\Intune\Logs\AdobeAcrobatReaderDC-Install.log`
