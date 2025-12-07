#Requires -Version 5.1
<#
    .SYNOPSIS
        Install Google Chrome Enterprise (latest version via Evergreen).

    .DESCRIPTION
        Downloads and installs the latest Google Chrome Enterprise x64 MSI
        directly from Google using the Evergreen PowerShell module.

    .NOTES
        Deploy via Intune as Win32 app.
        Install command: powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
#>
[CmdletBinding()]
param()

$AppName = "GoogleChrome"
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

    # Install/Import Evergreen
    Write-Log "Loading Evergreen module..."
    if (-not (Get-Module -Name Evergreen -ListAvailable)) {
        Write-Log "Installing Evergreen module..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Evergreen -Force -Scope AllUsers
    }
    Import-Module -Name Evergreen -Force

    # Get latest version
    Write-Log "Querying Evergreen for latest version..."
    $App = Get-EvergreenApp -Name "GoogleChrome" |
        Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "stable" -and $_.Type -eq "msi" } |
        Select-Object -First 1

    if (-not $App) { throw "Failed to get application info from Evergreen" }

    Write-Log "Found version: $($App.Version)"
    Write-Log "Download URL: $($App.URI)"

    # Download
    $InstallerPath = Join-Path -Path $TempPath -ChildPath "GoogleChromeEnterprise.msi"
    Write-Log "Downloading to: $InstallerPath"
    Invoke-WebRequest -Uri $App.URI -OutFile $InstallerPath -UseBasicParsing

    if (-not (Test-Path $InstallerPath)) { throw "Download failed" }
    Write-Log "Download complete"

    # Install
    Write-Log "Installing..."
    $Arguments = "/i `"$InstallerPath`" ALLUSERS=1 /quiet /norestart /log `"$LogPath\$AppName-MSI.log`""
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    Write-Log "Install exit code: $($Process.ExitCode)"

    # Post-install: Remove desktop shortcut
    Start-Sleep -Seconds 5
    $Shortcut = "C:\Users\Public\Desktop\Google Chrome.lnk"
    if (Test-Path $Shortcut) {
        Remove-Item -Path $Shortcut -Force -ErrorAction SilentlyContinue
        Write-Log "Removed desktop shortcut"
    }

    # Cleanup
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Installation complete"

    exit $Process.ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
