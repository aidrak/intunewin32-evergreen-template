#Requires -Version 5.1
<#
    .SYNOPSIS
        Uninstall ConnectWise ScreenConnect Agent.

    .DESCRIPTION
        Finds and removes the ScreenConnect Client by locating its GUID in the registry
        and running msiexec uninstall.

    .NOTES
        Deploy via Intune as Win32 app.
        Uninstall command: powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
#>

$AppName = "ScreenConnect"
$Thumbprint = "e6bb5af43151f034"
$BasePath = "C:\ProgramData\Intune"
$LogPath = Join-Path -Path $BasePath -ChildPath "Logs"
$LogFile = Join-Path -Path $LogPath -ChildPath "$AppName-Uninstall.log"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    Write-Host $LogMessage
}

function Get-GuidFromUninstallString {
    param([string]$UninstallString)
    if ($UninstallString -match '\{(.+?)\}') {
        return $Matches[1]
    }
    return $null
}

try {
    # Setup log directory
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }

    Write-Log "Starting $AppName uninstall"

    # Registry paths to search
    $UninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $ScreenConnect = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*ScreenConnect Client*$Thumbprint*" } |
        Select-Object -First 1

    if (-not $ScreenConnect) {
        Write-Log "ScreenConnect Client not found in registry"
        exit 0
    }

    $DisplayName = $ScreenConnect.DisplayName
    Write-Log "Found: $DisplayName"

    $Guid = Get-GuidFromUninstallString -UninstallString $ScreenConnect.UninstallString

    if (-not $Guid) {
        Write-Log "ERROR: Could not extract GUID from uninstall string: $($ScreenConnect.UninstallString)"
        exit 1
    }

    Write-Log "Product GUID: {$Guid}"
    Write-Log "Uninstalling..."

    $Arguments = "/x `"{$Guid}`" /qn /norestart /log `"$LogPath\$AppName-MSI-Uninstall.log`""
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
    Write-Log "Uninstall exit code: $($Process.ExitCode)"

    if ($Process.ExitCode -eq 0) {
        Write-Log "$DisplayName has been uninstalled"
    }
    else {
        Write-Log "Uninstall may have failed, check MSI log for details"
    }

    exit $Process.ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
