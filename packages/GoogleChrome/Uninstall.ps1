#Requires -Version 5.1
<#
    .SYNOPSIS
        Uninstall Google Chrome.

    .NOTES
        Deploy via Intune as Win32 app.
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
#>
[CmdletBinding()]
param()

$AppName = "GoogleChrome"
$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Uninstall.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message" -ErrorAction SilentlyContinue
}

try {
    Write-Log "Starting $AppName uninstall"

    # Find Chrome in registry
    $UninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Chrome = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Google Chrome*" } |
        Select-Object -First 1

    if ($Chrome) {
        $ProductCode = $Chrome.PSChildName
        Write-Log "Found Chrome: $ProductCode"

        $Arguments = "/uninstall `"$ProductCode`" /quiet /norestart"
        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        Write-Log "Uninstall exit code: $($Process.ExitCode)"
        exit $Process.ExitCode
    }
    else {
        Write-Log "Chrome not found"
        exit 0
    }
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
