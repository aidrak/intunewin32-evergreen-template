#Requires -Version 5.1
<#
    .SYNOPSIS
        Install SentinelOne EDR Agent.

    .DESCRIPTION
        Installs the SentinelOne agent MSI with the provided Site Token.
        The MSI must be included in the package folder.

    .PARAMETER SiteToken
        The SentinelOne Site Token from your S1 console (Sentinels > Site Info > Site Token).

    .NOTES
        Deploy via Intune as Win32 app.
        Install command: powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -SiteToken "YOUR-SITE-TOKEN"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteToken
)

$AppName = "SentinelOne"
$BasePath = "C:\ProgramData\Intune"
$LogPath = Join-Path -Path $BasePath -ChildPath "Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Install.log"
$TempPath = Join-Path -Path $BasePath -ChildPath "Downloads\$AppName"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    Write-Host $LogMessage
}

try {
    # Setup directories
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory -Force | Out-Null }

    Write-Log "Starting $AppName installation"

    # Find the MSI in the script directory
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $MsiFile = Get-ChildItem -Path $ScriptDir -Filter "SentinelInstaller*.msi" | Select-Object -First 1

    if (-not $MsiFile) {
        throw "SentinelOne MSI not found in package folder: $ScriptDir"
    }

    Write-Log "Found MSI: $($MsiFile.Name)"

    # Copy MSI to temp location
    $TempMsi = Join-Path -Path $TempPath -ChildPath $MsiFile.Name
    Copy-Item -Path $MsiFile.FullName -Destination $TempMsi -Force
    Write-Log "Copied MSI to: $TempMsi"

    # Install with Site Token
    Write-Log "Installing SentinelOne agent..."
    $Arguments = "/i `"$TempMsi`" /quiet /norestart SITE_TOKEN=`"$SiteToken`" /log `"$LogPath\$AppName-MSI.log`""
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    Write-Log "Install exit code: $($Process.ExitCode)"

    # Cleanup
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Installation complete"

    exit $Process.ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
