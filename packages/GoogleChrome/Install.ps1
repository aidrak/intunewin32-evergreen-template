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

    # Get latest version
    Write-Log "Querying Evergreen for latest version..."
    $App = Get-EvergreenApp -Name "GoogleChrome" |
        Where-Object { $_.Architecture -eq "x64" -and $_.Channel -eq "stable" -and $_.Type -eq "msi" } |
        Select-Object -First 1

    if (-not $App) { throw "Failed to get application info from Evergreen" }

    Write-Log "Found version: $($App.Version)"
    Write-Log "Download URL: $($App.URI)"

    # Download using Save-EvergreenApp
    Write-Log "Downloading installer..."
    $Download = $App | Save-EvergreenApp -Path $TempPath -ErrorAction Stop

    if (-not $Download -or -not (Test-Path $Download.FullName)) { throw "Download failed" }
    Write-Log "Download complete: $($Download.FullName)"

    # Install
    Write-Log "Installing..."
    $Arguments = "/i `"$($Download.FullName)`" ALLUSERS=1 /quiet /norestart /log `"$LogPath\$AppName-MSI.log`""
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    Write-Log "Install exit code: $($Process.ExitCode)"

    # Post-install: Ensure desktop shortcut exists on public desktop
    Start-Sleep -Seconds 5
    $Shortcut = "C:\Users\Public\Desktop\Google Chrome.lnk"
    if (-not (Test-Path $Shortcut)) {
        $WshShell = New-Object -ComObject WScript.Shell
        $ShortcutObj = $WshShell.CreateShortcut($Shortcut)
        $ShortcutObj.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
        $ShortcutObj.WorkingDirectory = "C:\Program Files\Google\Chrome\Application"
        $ShortcutObj.Description = "Google Chrome"
        $ShortcutObj.Save()
        Write-Log "Created desktop shortcut"
    } else {
        Write-Log "Desktop shortcut already exists"
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
