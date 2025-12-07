#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Install Adobe Acrobat Reader DC MUI (VDI Optimized).

    .DESCRIPTION
        Installs Adobe Acrobat Reader DC Multi-language edition with VDI optimizations:
        - Applies VDI MST transform file
        - Disables thumbnail preview generation
        - Disables auto-updates
        - Disables browser integration
        - Suppresses upsell messages

    .NOTES
        Use with Microsoft Intune Win32 app deployment.
        Optimized for Citrix, RDS, and Azure Virtual Desktop environments.
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
    $LogFile = Join-Path -Path $LogPath -ChildPath "AdobeAcrobatReaderDCMUIVDI-Install.log"
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    function Write-Log {
        param([string]$Message, [int]$Level = 1)
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "[$TimeStamp] $Message"
    }

    $ScriptPath = $PSScriptRoot
}

process {
    try {
        Write-Log "Starting Adobe Acrobat Reader DC MUI VDI installation"

        # Stop any running Adobe processes
        $AdobeProcesses = @("AcroRd32", "Acrobat")
        foreach ($ProcessName in $AdobeProcesses) {
            Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
        }
        Write-Log "Stopped Adobe processes"

        # Find installer
        $Installer = Get-ChildItem -Path $ScriptPath -Filter "AcroRdr*MUI*.exe" | Select-Object -First 1
        if (-not $Installer) {
            $Installer = Get-ChildItem -Path $ScriptPath -Filter "AcroRdr*.exe" | Select-Object -First 1
        }
        if (-not $Installer) {
            throw "Adobe Reader MUI installer not found in $ScriptPath"
        }
        Write-Log "Found installer: $($Installer.Name)"

        # Check for MST transform file
        $MstFile = Join-Path -Path $ScriptPath -ChildPath "VDI-enUS.mst"
        $HasMst = Test-Path -Path $MstFile
        Write-Log "VDI transform file present: $HasMst"

        # Build install arguments
        if ($HasMst) {
            $Arguments = "/sALL /rps /l /msi TRANSFORMS=`"$MstFile`" EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1 /log `"$LogPath\AdobeAcrobatReaderDCMUIVDI-MSI.log`""
        }
        else {
            $Arguments = "/sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1 /log `"$LogPath\AdobeAcrobatReaderDCMUIVDI-MSI.log`""
        }
        Write-Log "Running: $($Installer.FullName) $Arguments"

        $Process = Start-Process -FilePath $Installer.FullName -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        Write-Log "Installation exit code: $($Process.ExitCode)"

        # Allow installation to complete
        Start-Sleep -Seconds 15

        # Post-install: Remove desktop shortcuts
        $Shortcuts = @(
            "C:\Users\Public\Desktop\Adobe Acrobat.lnk",
            "C:\Users\Public\Desktop\Adobe Acrobat DC.lnk",
            "C:\Users\Public\Desktop\Adobe Acrobat Reader.lnk",
            "C:\Users\Public\Desktop\Adobe Acrobat Reader DC.lnk"
        )
        foreach ($Shortcut in $Shortcuts) {
            if (Test-Path -Path $Shortcut) {
                Remove-Item -Path $Shortcut -Force -ErrorAction SilentlyContinue
                Write-Log "Removed shortcut: $Shortcut"
            }
        }

        # Post-install: Disable Adobe update services
        Write-Log "Configuring Adobe services for VDI..."
        Get-Service -Name "AdobeARMservice" -ErrorAction SilentlyContinue | Stop-Service -ErrorAction SilentlyContinue
        Get-Service -Name "AdobeARMservice" -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Disabled AdobeARMservice"

        # Remove scheduled tasks
        Get-ScheduledTask "Adobe Acrobat Update Task*" -ErrorAction SilentlyContinue |
            Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Removed Adobe update scheduled tasks"

        # Configure registry settings for VDI
        Write-Log "Applying VDI registry settings..."

        # Feature lockdown settings
        $RegPath = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $RegPath -Name "bIsSCReducedModeEnforcedEx" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $RegPath -Name "bAcroSuppressUpsell" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $RegPath -Name "bUpdater" -Value 0 -Type DWord -Force

        # IPM settings
        $IPMPath = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown\cIPM"
        if (-not (Test-Path $IPMPath)) {
            New-Item -Path $IPMPath -Force | Out-Null
        }
        Set-ItemProperty -Path $IPMPath -Name "bDontShowMsgWhenViewingDoc" -Value 0 -Type DWord -Force

        # Disable ARM update mode
        $ARMPath = "HKLM:\SOFTWARE\WOW6432Node\Adobe\Adobe ARM\Legacy\Reader\{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"
        if (-not (Test-Path $ARMPath)) {
            New-Item -Path $ARMPath -Force | Out-Null
        }
        Set-ItemProperty -Path $ARMPath -Name "Mode" -Value 0 -Type DWord -Force

        # Disable maintenance mode
        $InstallerPath = "HKLM:\SOFTWARE\Adobe\Adobe Acrobat\DC\Installer"
        if (-not (Test-Path $InstallerPath)) {
            New-Item -Path $InstallerPath -Force | Out-Null
        }
        Set-ItemProperty -Path $InstallerPath -Name "DisableMaintenance" -Value 1 -Type DWord -Force

        Write-Log "Adobe Acrobat Reader DC MUI VDI installation completed"
        exit $Process.ExitCode
    }
    catch {
        Write-Log "Installation failed: $_"
        exit 1
    }
}
