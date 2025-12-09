#Requires -Version 5.1
<#
    .SYNOPSIS
        Uninstall Adobe Acrobat DC Pro/Standard.

    .NOTES
        Deploy via Intune as Win32 app.
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
#>
[CmdletBinding()]
param()

$AppName = "AdobeAcrobatDC"
$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Uninstall.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message" -ErrorAction SilentlyContinue
}

try {
    Write-Log "Starting $AppName uninstall"

    # Stop Adobe processes
    Get-Process -Name "AcroRd32", "Acrobat", "AcroCEF", "AdobeCollabSync" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # Find Adobe Acrobat in registry
    $UninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Acrobat = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Adobe Acrobat*" -and $_.DisplayName -notlike "*Reader*" } |
        Select-Object -First 1

    if ($Acrobat) {
        $ProductCode = $Acrobat.PSChildName
        Write-Log "Found: $($Acrobat.DisplayName) - $ProductCode"
        $Arguments = "/uninstall `"$ProductCode`" /quiet /norestart"
        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        Write-Log "Uninstall exit code: $($Process.ExitCode)"
    }
    else {
        Write-Log "Adobe Acrobat DC not found"
    }

    exit 0
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
