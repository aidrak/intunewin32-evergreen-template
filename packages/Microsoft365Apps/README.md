# Microsoft 365 Apps Package

Deploys Microsoft 365 Apps using the Office Deployment Tool (ODT) with full customization support. All apps are included by default - exclude what you don't need.

## Default Configuration

| Setting | Value |
|---------|-------|
| **Product ID** | O365ProPlusRetail |
| **Channel** | Monthly Enterprise |
| **Architecture** | 64-bit |
| **Language** | en-us |
| **Shared Computer Licensing** | Disabled |
| **Desktop Shortcuts** | Created on Public Desktop |

### Apps Included by Default

| App | Exclude Parameter |
|-----|-------------------|
| Microsoft Word | `-ExcludeWord` |
| Microsoft Excel | `-ExcludeExcel` |
| Microsoft PowerPoint | `-ExcludePowerPoint` |
| Microsoft OneNote | `-ExcludeOneNote` |
| Microsoft Outlook (classic) | `-ExcludeOutlook` |
| Microsoft Outlook (new) | `-ExcludeNewOutlook` |
| Microsoft Access | `-ExcludeAccess` |
| Microsoft Publisher | `-ExcludePublisher` |
| Microsoft Teams | `-ExcludeTeams` |
| OneDrive | `-ExcludeOneDrive` |

### Always Excluded (Deprecated)
- Lync (Skype for Business)
- Groove (OneDrive for Business legacy)

---

## All Available Parameters

### Exclude Apps

| Parameter | Description |
|-----------|-------------|
| `-ExcludeTeams` | Exclude Microsoft Teams |
| `-ExcludeOneDrive` | Exclude OneDrive sync client |
| `-ExcludeWord` | Exclude Microsoft Word |
| `-ExcludeExcel` | Exclude Microsoft Excel |
| `-ExcludePowerPoint` | Exclude Microsoft PowerPoint |
| `-ExcludeOneNote` | Exclude Microsoft OneNote |
| `-ExcludeOutlook` | Exclude Microsoft Outlook (both classic and new) |
| `-ExcludeAccess` | Exclude Microsoft Access |
| `-ExcludePublisher` | Exclude Microsoft Publisher |
| `-ExcludeNewOutlook` | Exclude only the new Outlook app (keeps classic Outlook) |

### Other Options

| Parameter | Description |
|-----------|-------------|
| `-SetSharedActivation` | Enable Shared Computer Licensing for VDI/RDS/multi-user environments |
| `-SkipShortcuts` | Skip creating desktop shortcuts on Public Desktop |

---

## Intune Configuration

### Program

| Setting | Value |
|---------|-------|
| **Install command** | See examples below |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| **Install behavior** | System |
| **Device restart behavior** | Determine behavior based on return codes |

### Detection Rule

| Setting | Value |
|---------|-------|
| **Rule type** | File |
| **Path** | `C:\Program Files\Microsoft Office\root\Office16` |
| **File** | `WINWORD.EXE` |
| **Detection method** | File or folder exists |

> **Note:** If you exclude Word, change the detection to another app you're installing (e.g., `EXCEL.EXE` or `OUTLOOK.EXE`).

### Requirements

| Setting | Value |
|---------|-------|
| **OS architecture** | 64-bit |
| **Minimum OS** | Windows 10 1809 |

---

## Install Command Examples

### Full Suite (Default)
Installs everything: Word, Excel, PowerPoint, OneNote, Outlook, Access, Publisher, Teams, OneDrive.
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

### Without Teams
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -ExcludeTeams
```

### Without Teams and OneDrive
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -ExcludeTeams -ExcludeOneDrive
```

### Core Apps Only (Word, Excel, PowerPoint, Outlook)
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -ExcludeTeams -ExcludeOneDrive -ExcludeOneNote -ExcludeAccess -ExcludePublisher
```

### Minimal Install (Word, Excel, Outlook only)
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -ExcludeTeams -ExcludeOneDrive -ExcludePowerPoint -ExcludeOneNote -ExcludeAccess -ExcludePublisher
```

### VDI/RDS Environment (Shared Computer Licensing)
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SetSharedActivation
```

### VDI Without Teams/OneDrive
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SetSharedActivation -ExcludeTeams -ExcludeOneDrive
```

### Classic Outlook Only (No New Outlook)
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -ExcludeNewOutlook
```

### No Desktop Shortcuts
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SkipShortcuts
```

---

## One Package, Multiple Configurations

Build the `.intunewin` package once, then create multiple Win32 apps in Intune with different install commands:

| Intune App Name | Install Command |
|-----------------|-----------------|
| Microsoft 365 Apps - Full | `...\Install.ps1` |
| Microsoft 365 Apps - No Teams | `...\Install.ps1 -ExcludeTeams -ExcludeOneDrive` |
| Microsoft 365 Apps - Core Only | `...\Install.ps1 -ExcludeTeams -ExcludeOneDrive -ExcludeAccess -ExcludePublisher -ExcludeOneNote` |
| Microsoft 365 Apps - VDI | `...\Install.ps1 -SetSharedActivation -ExcludeTeams -ExcludeOneDrive` |

---

## Desktop Shortcuts

By default, the installer creates a scheduled task that runs after reboot to create desktop shortcuts on the Public Desktop (`C:\Users\Public\Desktop`) for all installed apps.

**Why a scheduled task?**
- Office installation continues in the background after ODT returns
- Shortcuts are created once Office apps are fully installed
- Task self-deletes after creating shortcuts

**To disable:** Use `-SkipShortcuts`

**Shortcut log:** `C:\ProgramData\Intune\Logs\M365Apps-Shortcuts.log`

---

## Logs

| Log | Path |
|-----|------|
| Install log | `C:\ProgramData\Intune\Logs\Microsoft365Apps-Install.log` |
| Shortcut log | `C:\ProgramData\Intune\Logs\M365Apps-Shortcuts.log` |

---

## Notes

- **Updates**: Managed automatically by Microsoft via CDN (Monthly Enterprise Channel)
- **RemoveMSI**: Automatically removes legacy MSI-based Office installations before installing
- **EULA**: Automatically accepted during silent install
- **Force App Shutdown**: Enabled - running Office apps will be closed during install
