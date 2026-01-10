# ScreenConnect (ConnectWise Control) Agent

Intune Win32 package for deploying the ConnectWise ScreenConnect agent with runtime MSI download.

## Overview

This package downloads the ScreenConnect MSI at deployment time from ConnectWise servers using parameterized Company, Site, and Token values. The package itself is universal - only the Intune install command changes per client.

## Prerequisites

1. Active ConnectWise Control subscription
2. Company, Site, and Agent Token from your ConnectWise Control portal

### Finding Your Parameters

In ConnectWise Control:
1. Navigate to **Admin > Sites**
2. Select your site/company
3. Find the **Agent Token** in the site settings
4. Note the exact **Company Name** and **Site Name** as configured

The token is a UUID like: `b76dab9c-6457-486a-abf4-e60879e93fb6`

## Build

```powershell
New-IntuneWinPackage -SourcePath "packages/ScreenConnect" -SetupFile "ScreenConnect.txt" -DestinationPath "packages/ScreenConnect"
```

## Intune Configuration

### Install Command

```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -CompanyName "Your Company Name" -SiteName "Your Site Name" -AgentToken "your-token-uuid"
```

**Example:**
```
powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -CompanyName "SecurServ Implementations" -SiteName "SecurServ Implementations" -AgentToken "b76dab9c-6457-486a-abf4-e60879e93fb6"
```

### Uninstall Command

```
powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

### Install Behavior

- **Install behavior:** System
- **Device restart behavior:** No specific action

### Requirements

- **Operating system architecture:** 64-bit (or 32-bit if needed)
- **Minimum operating system:** Windows 10 1607

### Detection Rules

Use a **custom detection script** with `Detect.ps1`:
- Script file: `Detect.ps1`
- Run script as 32-bit process: No
- Enforce script signature check: No

The detection script looks for `ScreenConnect Client (e6bb5af43151f034)` in the registry.

## Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `-CompanyName` | Yes | Company name from ConnectWise Control | `"SecurServ Implementations"` |
| `-SiteName` | Yes | Site name from ConnectWise Control | `"Main Office"` |
| `-AgentToken` | Yes | Agent token UUID | `"b76dab9c-6457-486a-abf4-e60879e93fb6"` |

## How It Works

1. The install script sanitizes Company and Site names (spaces become underscores)
2. Constructs a download URL using the pattern:
   ```
   https://prod.setup.itsupport247.net/windows/BareboneAgent/32/{Site}-{Company}_Windows_OS_ITSPlatform_TKN{Token}/MSI/setup
   ```
3. Downloads the MSI (the URL redirects to an S3 bucket)
4. Installs silently with `msiexec /i ... ALLUSERS=1 /qn /norestart`
5. Cleans up temporary files

## Log Files

- **Install log:** `C:\ProgramData\Intune\Logs\ScreenConnect-Install.log`
- **MSI install log:** `C:\ProgramData\Intune\Logs\ScreenConnect-MSI.log`
- **Uninstall log:** `C:\ProgramData\Intune\Logs\ScreenConnect-Uninstall.log`

## Multi-Client Deployment

Since each client requires unique Company/Site/Token values, you have two options:

1. **Separate Intune apps per client:** Create a copy of the app in Intune for each client with their specific install command
2. **Single package, multiple assignments:** Use the same .intunewin file but configure different install commands in each assignment (if Intune supports this for your scenario)

## Troubleshooting

### Download Fails
- Verify the Company/Site/Token values are correct
- Check that the target machine has internet access
- Review `ScreenConnect-Install.log` for the exact URL being used
- Test the URL manually in a browser (it should download an MSI)

### Detection Fails
- The thumbprint `e6bb5af43151f034` is standard for ConnectWise Control
- If using a self-hosted ScreenConnect server, the thumbprint may differ
- Check registry manually: `Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*ScreenConnect*" }`

### Special Characters in Names
The script sanitizes Company/Site names:
- Spaces become underscores
- Special characters are replaced with underscores
- If your names have unusual characters, verify the constructed URL matches what ConnectWise expects
