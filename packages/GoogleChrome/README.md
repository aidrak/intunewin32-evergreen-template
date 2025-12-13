# Google Chrome Package

Deploys Google Chrome Enterprise x64 using the Evergreen module to always install the latest version.

## Features

- Downloads latest stable x64 MSI from Google
- Silent install with `ALLUSERS=1`
- Creates desktop shortcut on Public Desktop

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
| **Path** | `C:\Program Files\Google\Chrome\Application` |
| **File** | `chrome.exe` |
| **Detection method** | File or folder exists |

### Requirements

| Setting | Value |
|---------|-------|
| **Operating system architecture** | 64-bit |
| **Minimum operating system** | Windows 10 1809 |

---

## Notes

- **Logs**: `C:\ProgramData\Intune\Logs\GoogleChrome-Install.log`
- **MSI Log**: `C:\ProgramData\Intune\Logs\GoogleChrome-MSI.log`
