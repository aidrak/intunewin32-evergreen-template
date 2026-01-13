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
| **Return codes** | `0` = Success, `1641` = Hard reboot (defaults are fine) |

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

By default, the installer creates desktop shortcuts on the Public Desktop (`C:\Users\Public\Desktop`) for all installed apps immediately after Office installation completes.

The script polls for Office Click-to-Run completion (up to 60 minutes) using:
- Process monitoring (OfficeC2RClient.exe)
- File existence checks (WINWORD.EXE)
- Registry verification (VersionToReport)

**To disable:** Use `-SkipShortcuts`

---

## MSIX App Removal

Microsoft bundles MSIX versions of Teams and New Outlook with Windows 11 and Office. The ODT `ExcludeApp` directive may not reliably prevent their installation. This script handles cleanup automatically.

### Teams Removal (`-ExcludeTeams`)

When specified, the installer will:
1. Exclude Teams from the ODT configuration
2. Remove the MSIX Teams package if it was installed anyway
3. Remove the provisioned package to prevent future installs for new users

### New Outlook Removal (`-ExcludeNewOutlook`)

When specified, the installer will:
1. Exclude New Outlook from the ODT configuration
2. Remove the OutlookForWindows MSIX package if present
3. Remove the provisioned package to prevent future installs for new users

> **Tip:** If you want classic Outlook only, use `-ExcludeNewOutlook`. If you want no Outlook at all, use `-ExcludeOutlook` (excludes both).

---

## Reboot Handling

The script exits with code **1641** (hard reboot) to signal Intune that a restart is required.

### Intune Return Code Configuration

| Return Code | Type | Behavior |
|-------------|------|----------|
| 1641 | Hard reboot | Forces restart with countdown (default 120 min). Blocks next app until reboot. |
| 3010 | Soft reboot | Notifies user via toast notification only. During ESP, batches reboots at end. |

### Intune Settings (Program Page)

Ensure these settings in your Win32 app configuration:

| Setting | Recommended Value |
|---------|-------------------|
| **Device restart behavior** | Determine behavior based on return codes |
| **Return codes** | `1641` → Hard reboot (default) |

If you prefer a **soft reboot** (notification only, no forced restart):
- Change the script to `exit 3010` instead of `exit 1641`, OR
- Change `1641` to "Soft reboot" in Intune return codes

---

## Logs

| Log | Path |
|-----|------|
| Install log | `C:\ProgramData\Intune\Logs\Microsoft365Apps-Install.log` |

---

## Notes

- **Updates**: Managed automatically by Microsoft via CDN (Monthly Enterprise Channel)
- **RemoveMSI**: Automatically removes legacy MSI-based Office installations before installing
- **EULA**: Automatically accepted during silent install
- **Force App Shutdown**: Enabled - running Office apps will be closed during install
- **Install Duration**: Script waits for Office Click-to-Run to complete (up to 60 minutes) before exiting
