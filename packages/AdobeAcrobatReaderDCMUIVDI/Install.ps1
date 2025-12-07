#Requires -Version 5.1
<#
    .SYNOPSIS
        Install Adobe Acrobat Reader DC MUI VDI (latest version via Evergreen).

    .DESCRIPTION
        Downloads and installs the latest Adobe Acrobat Reader DC Multi-language x64
        with VDI optimizations using the Evergreen PowerShell module.

        VDI Optimizations:
        - Disabled thumbnail preview generation
        - Disabled auto-updates
        - Disabled browser integration
        - Suppressed upsell messages

    .NOTES
        Deploy via Intune as Win32 app.
        Install command: powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
        Optimized for Citrix, RDS, and Azure Virtual Desktop.
#>
[CmdletBinding()]
param()

$AppName = "AdobeAcrobatReaderDCMUIVDI"
$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Install.log"
$TempPath = Join-Path -Path $env:TEMP -ChildPath $AppName

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    Write-Host $LogMessage
}

try {
    # Setup
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory -Force | Out-Null }

    Write-Log "Starting $AppName installation (VDI Optimized)"

    # Stop any running Adobe processes
    Get-Process -Name "AcroRd32", "Acrobat" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Log "Stopped Adobe processes"

    # Install/Import Evergreen
    Write-Log "Loading Evergreen module..."
    if (-not (Get-Module -Name Evergreen -ListAvailable)) {
        Write-Log "Installing Evergreen module..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Evergreen -Force -Scope AllUsers
    }
    Import-Module -Name Evergreen -Force

    # Get latest version (MUI = Multi-language)
    Write-Log "Querying Evergreen for latest MUI version..."
    $App = Get-EvergreenApp -Name "AdobeAcrobatReaderDC" |
        Where-Object { $_.Architecture -eq "x64" -and $_.Language -eq "MUI" } |
        Select-Object -First 1

    if (-not $App) { throw "Failed to get application info from Evergreen" }

    Write-Log "Found version: $($App.Version)"
    Write-Log "Download URL: $($App.URI)"

    # Download
    $FileName = Split-Path -Path $App.URI -Leaf
    $InstallerPath = Join-Path -Path $TempPath -ChildPath $FileName
    Write-Log "Downloading to: $InstallerPath"
    Invoke-WebRequest -Uri $App.URI -OutFile $InstallerPath -UseBasicParsing

    if (-not (Test-Path $InstallerPath)) { throw "Download failed" }
    Write-Log "Download complete"

    # Install with VDI optimizations
    Write-Log "Installing with VDI optimizations..."
    $Arguments = "/sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1 /log `"$LogPath\$AppName-MSI.log`""
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    Write-Log "Install exit code: $($Process.ExitCode)"

    # Wait for install to complete
    Start-Sleep -Seconds 15

    # Post-install: Remove desktop shortcuts
    $Shortcuts = @(
        "C:\Users\Public\Desktop\Adobe Acrobat.lnk",
        "C:\Users\Public\Desktop\Adobe Acrobat DC.lnk",
        "C:\Users\Public\Desktop\Adobe Acrobat Reader.lnk",
        "C:\Users\Public\Desktop\Adobe Acrobat Reader DC.lnk"
    )
    foreach ($Shortcut in $Shortcuts) {
        if (Test-Path $Shortcut) {
            Remove-Item -Path $Shortcut -Force -ErrorAction SilentlyContinue
            Write-Log "Removed: $Shortcut"
        }
    }

    # Post-install: Disable update services
    Write-Log "Disabling Adobe update services..."
    Get-Service -Name "AdobeARMservice" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    Get-Service -Name "AdobeARMservice" -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled -ErrorAction SilentlyContinue

    # Remove scheduled tasks
    Get-ScheduledTask -TaskName "Adobe Acrobat Update Task*" -ErrorAction SilentlyContinue |
        Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    # VDI Registry settings
    Write-Log "Applying VDI registry settings..."

    # Feature lockdown
    $RegPath = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
    if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    Set-ItemProperty -Path $RegPath -Name "bIsSCReducedModeEnforcedEx" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $RegPath -Name "bAcroSuppressUpsell" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $RegPath -Name "bUpdater" -Value 0 -Type DWord -Force

    # IPM settings
    $IPMPath = "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown\cIPM"
    if (-not (Test-Path $IPMPath)) { New-Item -Path $IPMPath -Force | Out-Null }
    Set-ItemProperty -Path $IPMPath -Name "bDontShowMsgWhenViewingDoc" -Value 0 -Type DWord -Force

    # Disable ARM update mode
    $ARMPath = "HKLM:\SOFTWARE\WOW6432Node\Adobe\Adobe ARM\Legacy\Reader\{AC76BA86-7AD7-1033-7B44-AC0F074E4100}"
    if (-not (Test-Path $ARMPath)) { New-Item -Path $ARMPath -Force | Out-Null }
    Set-ItemProperty -Path $ARMPath -Name "Mode" -Value 0 -Type DWord -Force

    # Disable maintenance
    $InstallerRegPath = "HKLM:\SOFTWARE\Adobe\Adobe Acrobat\DC\Installer"
    if (-not (Test-Path $InstallerRegPath)) { New-Item -Path $InstallerRegPath -Force | Out-Null }
    Set-ItemProperty -Path $InstallerRegPath -Name "DisableMaintenance" -Value 1 -Type DWord -Force

    # Cleanup
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "VDI installation complete"

    exit $Process.ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
