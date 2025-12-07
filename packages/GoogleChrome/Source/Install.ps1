#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Install Google Chrome Enterprise x64.

    .DESCRIPTION
        Downloads and installs the latest Google Chrome Enterprise using Evergreen.
        Configures initial preferences and removes desktop shortcuts.

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
    $LogFile = Join-Path -Path $LogPath -ChildPath "GoogleChrome-Install.log"
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    function Write-Log {
        param([string]$Message, [int]$Level = 1)
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogMessage = "[$TimeStamp] $Message"
        Add-Content -Path $LogFile -Value $LogMessage
        if ($Level -eq 3) { Write-Error $Message }
        elseif ($Level -eq 2) { Write-Warning $Message }
        else { Write-Verbose $Message }
    }

    $ScriptPath = $PSScriptRoot
}

process {
    try {
        Write-Log "Starting Google Chrome installation"

        # Load configuration
        $ConfigPath = Join-Path -Path $ScriptPath -ChildPath "Install.json"
        $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

        # Find MSI file
        $MsiFile = Get-ChildItem -Path $ScriptPath -Filter "*.msi" | Select-Object -First 1
        if (-not $MsiFile) {
            throw "MSI file not found in $ScriptPath"
        }
        Write-Log "Found installer: $($MsiFile.Name)"

        # Install Chrome
        $Arguments = "/i `"$($MsiFile.FullName)`" ALLUSERS=1 /quiet /norestart /log `"$LogPath\GoogleChrome-MSI.log`""
        Write-Log "Running: msiexec.exe $Arguments"

        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        Write-Log "Installation exit code: $($Process.ExitCode)"

        # Wait for installation to settle
        Start-Sleep -Seconds 10

        # Post-install: Remove desktop shortcut
        $DesktopShortcut = "C:\Users\Public\Desktop\Google Chrome.lnk"
        if (Test-Path -Path $DesktopShortcut) {
            Remove-Item -Path $DesktopShortcut -Force -ErrorAction SilentlyContinue
            Write-Log "Removed desktop shortcut"
        }

        # Post-install: Copy initial preferences
        $PrefsSource = Join-Path -Path $ScriptPath -ChildPath "initial_preferences"
        $PrefsDestination = "C:\Program Files\Google\Chrome\Application\initial_preferences"
        if (Test-Path -Path $PrefsSource) {
            # Remove existing initial_preferences if present
            if (Test-Path -Path $PrefsDestination) {
                Remove-Item -Path $PrefsDestination -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -Path $PrefsSource -Destination $PrefsDestination -Force
            Write-Log "Copied initial_preferences"
        }

        Write-Log "Google Chrome installation completed"
        exit $Process.ExitCode
    }
    catch {
        Write-Log "Installation failed: $_" -Level 3
        exit 1
    }
}
