# Microsoft 365 Apps Package

Deploys Microsoft 365 Apps using the Office Deployment Tool (ODT) with configurable options.

## Default Configuration

| Setting | Value |
|---------|-------|
| **Channel** | Monthly Enterprise |
| **Architecture** | 64-bit |
| **Language** | en-us |
| **Shared Computer Licensing** | Disabled |
| **Desktop Shortcuts** | Always created on Public Desktop |

### Apps Always Included
- Word, Excel, PowerPoint, OneNote
- Outlook (classic + new)
- Access, Publisher

### Apps Excluded by Default
- Teams (use `-IncludeTeams` to add)
- OneDrive (use `-IncludeOneDrive` to add)

### Always Excluded
- Lync (Skype for Business) - deprecated
- Groove (OneDrive for Business legacy) - deprecated

---

## Intune Configuration

### Program

| Setting | Value |
|---------|-------|
| **Install command** | See examples below |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| **Install behavior** | System |

### Detection Rule

| Setting | Value |
|---------|-------|
| **Rule type** | File |
| **Path** | `C:\Program Files\Microsoft Office\root\Office16` |
| **File** | `WINWORD.EXE` |
| **Detection method** | File or folder exists |

---

## Available Switches

| Switch | Description |
|--------|-------------|
| `-IncludeTeams` | Add Microsoft Teams (switches to O365ProPlusRetail SKU) |
| `-IncludeOneDrive` | Add OneDrive sync client |
| `-SetSharedActivation` | Enable Shared Computer Licensing (for VDI/RDS) |

---

## Install Command Examples

**Standard Workstation (Default)**
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

**With Teams and OneDrive**
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeTeams -IncludeOneDrive
```

**VDI/RDS Environment**
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SetSharedActivation
```

**Full Suite for VDI with Teams**
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeTeams -IncludeOneDrive -SetSharedActivation
```

---

## Notes

- **One package, multiple Intune apps**: Build once, create different Win32 apps in Intune with different install commands
- **Teams SKU**: `-IncludeTeams` uses `O365ProPlusRetail`; without it uses `O365ProPlusEEANoTeamsRetail` (EU compliant)
- **RemoveMSI**: Automatically removes legacy MSI-based Office installations
- **Updates**: Managed by Microsoft via CDN
- **Logs**: `C:\ProgramData\Intune\Logs\Microsoft365Apps-Install.log`
