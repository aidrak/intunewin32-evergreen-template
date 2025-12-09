#Requires -Version 5.1
<#
    .SYNOPSIS
        Install Adobe Acrobat DC Pro/Standard (latest version via Evergreen).

    .DESCRIPTION
        Downloads and installs the latest Adobe Acrobat DC Pro/Standard x64
        directly from Adobe using the Evergreen PowerShell module.
        Configured for VDI/multi-user environments with ALLUSERS flag.

    .NOTES
        Deploy via Intune as Win32 app.
        Install command: powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
        Requires valid Adobe licensing (volume license, named user, or subscription).
#>
[CmdletBinding()]
param()

$AppName = "AdobeAcrobatDC"
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

    Write-Log "Starting $AppName installation"

    # Stop any running Adobe processes
    Get-Process -Name "AcroRd32", "Acrobat", "AcroCEF", "AdobeCollabSync" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Log "Stopped Adobe processes"

    # Trust PSGallery and install/update Evergreen
    Write-Log "Configuring PowerShell Gallery..."
    if (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
        Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.208 -Force | Out-Null
        Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
    }

    Write-Log "Installing/updating Evergreen module..."
    if (-not (Get-Module -Name Evergreen -ListAvailable)) {
        Install-Module -Name Evergreen -Force -Scope AllUsers
    }
    Import-Module -Name Evergreen -Force
    Update-Module -Name Evergreen -Force -ErrorAction SilentlyContinue

    # Get latest version - AdobeAcrobatProStdDC provides Pro/Standard DC downloads
    Write-Log "Querying Evergreen for latest version..."
    $App = Get-EvergreenApp -Name "AdobeAcrobatProStdDC" |
        Where-Object { $_.Architecture -eq "x64" } |
        Select-Object -First 1

    if (-not $App) { throw "Failed to get application info from Evergreen" }

    Write-Log "Found version: $($App.Version)"
    Write-Log "Download URL: $($App.URI)"

    # Download using Save-EvergreenApp
    Write-Log "Downloading installer..."
    $Download = $App | Save-EvergreenApp -Path $TempPath -ErrorAction Stop

    if (-not $Download -or -not (Test-Path $Download.FullName)) { throw "Download failed" }
    Write-Log "Download complete: $($Download.FullName)"

    # Check if download is a ZIP file and extract it
    $InstallerPath = $Download.FullName
    if ($Download.FullName -like "*.zip") {
        Write-Log "Extracting ZIP archive..."
        $ExtractPath = Join-Path -Path $TempPath -ChildPath "Extracted"
        Expand-Archive -Path $Download.FullName -DestinationPath $ExtractPath -Force

        # Find setup.exe in extracted folder
        $SetupExe = Get-ChildItem -Path $ExtractPath -Recurse -Filter "setup.exe" | Select-Object -First 1
        if (-not $SetupExe) {
            # Try Setup.exe (case sensitivity)
            $SetupExe = Get-ChildItem -Path $ExtractPath -Recurse -Filter "Setup.exe" | Select-Object -First 1
        }
        if (-not $SetupExe) { throw "Could not find setup.exe in extracted archive" }

        $InstallerPath = $SetupExe.FullName
        Write-Log "Found installer: $InstallerPath"
    }

    # Install with ALLUSERS for VDI/multi-user environments
    Write-Log "Installing..."
    $Arguments = "/sAll /rs /rps /msi ALLUSERS=1 EULA_ACCEPT=YES DISABLEDESKTOPSHORTCUT=1"
    $Process = Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    Write-Log "Install exit code: $($Process.ExitCode)"

    # Wait for install to complete
    Start-Sleep -Seconds 15

    # Cleanup
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Installation complete"

    exit $Process.ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
