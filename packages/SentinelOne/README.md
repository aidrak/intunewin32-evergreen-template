# SentinelOne EDR Agent

SentinelOne endpoint detection and response agent deployment via Intune Win32 app.

**Note:** This package uses a direct MSI installer (not Evergreen). You must download the MSI from your SentinelOne console.

## Prerequisites

1. Download the SentinelOne MSI from your S1 console: **Sentinels > Packages**
2. Copy your Site Token from: **Sentinels > Site Info > Site Token**
3. Place the MSI in this folder (naming: `SentinelInstaller*.msi`)

## Build Package

```powershell
New-IntuneWinPackage -SourcePath "packages/SentinelOne" -SetupFile "SentinelOne.txt" -DestinationPath "packages/SentinelOne"
```

## Intune Configuration

### App Information
| Field | Value |
|-------|-------|
| Name | SentinelOne Agent |
| Description | SentinelOne EDR Agent |
| Publisher | SentinelOne |

### Program
| Field | Value |
|-------|-------|
| Install command | `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SiteToken "YOUR-SITE-TOKEN-HERE"` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | System |
| Device restart behavior | Determine behavior based on return codes |

### Requirements
| Field | Value |
|-------|-------|
| Operating system architecture | 64-bit |
| Minimum operating system | Windows 10 1607 |

### Detection Rules
| Field | Value |
|-------|-------|
| Rule type | Registry |
| Key path | `HKEY_LOCAL_MACHINE\SOFTWARE\Sentinel Labs\Sentinel Agent` |
| Detection method | Key exists |

## Important Notes

### Uninstall Requires Console Approval
SentinelOne agents cannot be uninstalled without first approving the action in the S1 console:
1. Go to **Sentinels** in your S1 console
2. Select the device
3. Click **Actions > Uninstall**
4. Approve the uninstall request

Only after approval will the Intune uninstall command succeed.

### Updating the Agent
To deploy a new version:
1. Download the new MSI from your S1 console
2. Replace the MSI file in this folder
3. Rebuild the .intunewin package
4. Upload to Intune as a new version

## Logs
- Install log: `C:\ProgramData\Intune\Logs\SentinelOne-Install.log`
- MSI log: `C:\ProgramData\Intune\Logs\SentinelOne-MSI.log`
- Uninstall log: `C:\ProgramData\Intune\Logs\SentinelOne-Uninstall.log`
