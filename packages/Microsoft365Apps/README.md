# Microsoft 365 Apps Package

Deploys Microsoft 365 Apps using the Office Deployment Tool (ODT) with configurable options.

## Default Configuration

| Setting | Default Value |
|---------|---------------|
| **Channel** | Monthly Enterprise |
| **Architecture** | 64-bit |
| **Language** | en-us |
| **Shared Computer Licensing** | Enabled |
| **Display Level** | None (silent) |
| **Accept EULA** | TRUE |

### Default Apps Included
- Word
- Excel
- PowerPoint
- OneNote

### Default Apps Excluded
- Teams (use `-IncludeTeams` to add)
- Outlook Classic (use `-IncludeOutlook` to add)
- Outlook New (use `-IncludeOutlookNew` to add)
- OneDrive (use `-IncludeOneDrive` to add)
- Access (use `-IncludeAccess` to add)
- Publisher (use `-IncludePublisher` to add)

### Always Excluded
- Lync (Skype for Business) - deprecated
- Groove (OneDrive for Business legacy) - deprecated

---

## Available Switches

| Switch | Description |
|--------|-------------|
| `-IncludeTeams` | Add Microsoft Teams (switches to O365ProPlusRetail SKU) |
| `-IncludeOutlook` | Add classic Outlook |
| `-IncludeOutlookNew` | Add new Outlook for Windows |
| `-IncludeOneDrive` | Add OneDrive sync client |
| `-IncludeAccess` | Add Microsoft Access |
| `-IncludePublisher` | Add Microsoft Publisher |
| `-NoSharedComputer` | Disable Shared Computer Licensing |

---

## Intune Deployment Examples

### Minimal (Default)
Word, Excel, PowerPoint, OneNote only. Ideal for VDI/shared environments.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### Standard Workstation
Core apps plus Outlook and OneDrive, no shared licensing.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeOutlook -IncludeOneDrive -NoSharedComputer
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### Full Suite with Teams
All apps including Teams.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeTeams -IncludeOutlook -IncludeOutlookNew -IncludeOneDrive -IncludeAccess -IncludePublisher
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### VDI/RDS Environment
Minimal apps with shared licensing (default), add Outlook for email.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeOutlook
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
Install behavior:  System
```

### New Outlook Only (No Classic)
Modern Outlook experience without classic Outlook.

```
Install command:   powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -IncludeOutlookNew -IncludeOneDrive -NoSharedComputer
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
- **RemoveMSI**: Automatically removes legacy MSI-based Office installations
- **Updates**: Managed by Microsoft via CDN (Updates Enabled=TRUE)
- **Logs**: `C:\ProgramData\Intune\Logs\Microsoft365Apps-Install.log`
