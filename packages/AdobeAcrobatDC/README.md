# Adobe Acrobat DC Package

Deploys Adobe Acrobat DC Pro/Standard x64 using the Evergreen module to always install the latest version.

**Requires valid Adobe licensing** (volume license, named user, or subscription).

## Features

- Downloads latest x64 version from Adobe
- Extracts ZIP and runs setup.exe
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
| **Path** | `C:\Program Files\Adobe\Acrobat DC\Acrobat` |
| **File** | `Acrobat.exe` |
| **Detection method** | File or folder exists |

### Requirements

| Setting | Value |
|---------|-------|
| **Operating system architecture** | 64-bit |
| **Minimum operating system** | Windows 10 1809 |

---

## Notes

- **Logs**: `C:\ProgramData\Intune\Logs\AdobeAcrobatDC-Install.log`
- This installs the Pro/Standard version - licensing determines which features are available
