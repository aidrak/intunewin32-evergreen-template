# Microsoft 365 Apps Package

Deploys Microsoft 365 Apps using the Office Deployment Tool (ODT) with configurable options.

## Default Configuration

| Setting | Default Value |
|---------|---------------|
| **Channel** | Monthly Enterprise |
| **Architecture** | 64-bit |
| **Language** | en-us |
| **Shared Computer Licensing** | Disabled |
| **Display Level** | None (silent) |
| **Accept EULA** | TRUE |
| **Desktop Shortcuts** | Always created on Public Desktop |

### Apps Always Included
- Word
- Excel
- PowerPoint
- OneNote
- Outlook (classic)
- Outlook (new)
- Access
- Publisher

### Apps Excluded by Default
- Teams (use `-IncludeTeams` to add)
- OneDrive (use `-IncludeOneDrive` to add)

### Always Excluded
- Lync (Skype for Business) - deprecated
- Groove (OneDrive for Business legacy) - deprecated

---

## Available Switches

| Switch | Description |
|--------|-------------|
| `-IncludeTeams` | Add Microsoft Teams (switches to O365ProPlusRetail SKU) |
| `-IncludeOneDrive` | Add OneDrive sync client |
| `-SetSharedActivation` | Enable Shared Computer Licensing (for VDI/RDS) |

---

## Intune Deployment Examples

### Standard Workstation (Default)
Full Office suite for individual workstations.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### With Teams and OneDrive
Full suite plus collaboration tools.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeTeams -IncludeOneDrive
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### VDI/RDS Environment
Full suite with shared computer licensing.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SetSharedActivation
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### Full Suite for VDI with Teams
Everything enabled for shared environments.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeTeams -IncludeOneDrive -SetSharedActivation
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

---

## Detection Script

The included `Detect.ps1` checks for any Microsoft 365 Click-to-Run installation.

**Detection method:** Registry key `HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`

---

## Build Package

```powershell
pwsh
New-IntuneWinPackage -SourcePath "packages/Microsoft365Apps" -SetupFile "Microsoft365Apps.txt" -DestinationPath "packages/Microsoft365Apps"
```

---

## Notes

- **One package, multiple Intune apps**: Build once, create different Win32 apps in Intune with different install commands
- **Teams SKU**: `-IncludeTeams` uses `O365ProPlusRetail`; without it uses `O365ProPlusEEANoTeamsRetail` (EU compliant, no Teams)
- **Desktop Shortcuts**: Always created on Public Desktop for all installed apps
- **RemoveMSI**: Automatically removes legacy MSI-based Office installations
- **Updates**: Managed by Microsoft via CDN (Updates Enabled=TRUE)
- **Logs**: `C:\ProgramData\Intune\Logs\Microsoft365Apps-Install.log`
