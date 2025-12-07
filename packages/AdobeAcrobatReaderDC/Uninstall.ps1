#Requires -Version 5.1
<#
    .SYNOPSIS
        Uninstall Adobe Acrobat Reader DC.

    .NOTES
        Deploy via Intune as Win32 app.
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
#>
[CmdletBinding()]
param()

$AppName = "AdobeAcrobatReaderDC"
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
    Get-Process -Name "AcroRd32", "Acrobat" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # Known product codes for Adobe Reader DC
    $ProductCodes = @(
        "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}",  # Reader DC
        "{AC76BA86-1033-FF00-7760-BC15014EA700}"   # Reader DC MUI
    )

    $Uninstalled = $false
    foreach ($ProductCode in $ProductCodes) {
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode"
        if (Test-Path $RegPath) {
            Write-Log "Found: $ProductCode"
            $Arguments = "/uninstall `"$ProductCode`" /quiet /norestart"
            $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            Write-Log "Uninstall exit code: $($Process.ExitCode)"
            $Uninstalled = $true
        }
    }

    if (-not $Uninstalled) {
        Write-Log "Adobe Reader DC not found"
    }

    exit 0
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
