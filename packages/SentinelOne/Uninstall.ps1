#Requires -Version 5.1
<#
    .SYNOPSIS
        Uninstall SentinelOne EDR Agent.

    .DESCRIPTION
        Removes the SentinelOne agent via MSI uninstall.

        IMPORTANT: SentinelOne requires console approval before uninstall will work.
        You must first approve the uninstall in the S1 console (Sentinels > Select device > Actions > Uninstall).

    .NOTES
        Deploy via Intune as Win32 app.
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
#>
[CmdletBinding()]
param()

$AppName = "SentinelOne"
$LogPath = "C:\ProgramData\Intune\Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Uninstall.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message" -ErrorAction SilentlyContinue
    Write-Host $Message
}

try {
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }

    Write-Log "Starting $AppName uninstall"
    Write-Log "NOTE: Uninstall requires prior approval in SentinelOne console"

    # Find SentinelOne in registry
    $UninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $S1 = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*SentinelOne*" -or $_.DisplayName -like "*Sentinel Agent*" } |
        Select-Object -First 1

    if ($S1) {
        $ProductCode = $S1.PSChildName
        Write-Log "Found SentinelOne: $($S1.DisplayName) - $ProductCode"

        $Arguments = "/x `"$ProductCode`" /quiet /norestart /log `"$LogPath\$AppName-Uninstall-MSI.log`""
        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        Write-Log "Uninstall exit code: $($Process.ExitCode)"

        if ($Process.ExitCode -ne 0) {
            Write-Log "Uninstall may have failed - ensure uninstall is approved in S1 console"
        }

        exit $Process.ExitCode
    }
    else {
        Write-Log "SentinelOne not found in registry"
        exit 0
    }
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
