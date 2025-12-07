#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Uninstall Google Chrome.

    .DESCRIPTION
        Removes Google Chrome by detecting the installed MSI and running msiexec uninstall.

    .NOTES
        Use with Microsoft Intune Win32 app deployment.
#>
[CmdletBinding()]
param()

begin {
    # Ensure 64-bit process
    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        $Process = Start-Process -FilePath "$env:SystemRoot\Sysnative\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        exit $Process.ExitCode
    }

    # Setup logging
    $LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    $LogFile = Join-Path -Path $LogPath -ChildPath "GoogleChrome-Uninstall.log"

    function Write-Log {
        param([string]$Message, [int]$Level = 1)
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "[$TimeStamp] $Message"
    }

    function Get-InstalledSoftware {
        param([string]$Name)
        $UninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$Name*" -and $_.SystemComponent -ne 1 }
    }
}

process {
    try {
        Write-Log "Starting Google Chrome uninstallation"

        # Find Chrome installation
        $Chrome = Get-InstalledSoftware -Name "Google Chrome"

        if ($Chrome) {
            $ProductCode = $Chrome.PSChildName
            Write-Log "Found Chrome with product code: $ProductCode"

            # Uninstall via MSI
            $Arguments = "/uninstall `"$ProductCode`" /quiet /norestart /log `"$LogPath\GoogleChrome-Uninstall-MSI.log`""
            Write-Log "Running: msiexec.exe $Arguments"

            $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            Write-Log "Uninstall exit code: $($Process.ExitCode)"

            exit $Process.ExitCode
        }
        else {
            Write-Log "Google Chrome not found"
            exit 0
        }
    }
    catch {
        Write-Log "Uninstallation failed: $_"
        exit 1
    }
}
