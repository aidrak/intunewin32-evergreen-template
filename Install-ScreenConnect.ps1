#Requires -Version 5.1
<#
    .SYNOPSIS
        Standalone script to download and install ConnectWise ScreenConnect Agent.

    .DESCRIPTION
        Downloads and installs the ScreenConnect/ConnectWise Control agent MSI
        using the provided Company, Site, and Token parameters.
        Designed to run directly on a machine under the SYSTEM account.

    .NOTES
        Run as: powershell.exe -ExecutionPolicy Bypass -File .\Install-ScreenConnect.ps1
#>

# ============================================================
# CONFIGURATION - Replace these values with your own
# ============================================================
$CompanyName = "YOUR_COMPANY_NAME"
$SiteName    = "YOUR_SITE_NAME"
$AgentToken  = "YOUR_AGENT_TOKEN_UUID"
# ============================================================

$AppName = "ScreenConnect"
$LogFile = "C:\temp\screenconnect_install.txt"
$TempPath = "C:\temp\ScreenConnect_Download"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    Write-Host $LogMessage
}

function ConvertTo-UrlSafeName {
    param([string]$Name)
    $safeName = $Name -replace '\s+', '_'
    $safeName = $safeName -replace '[^a-zA-Z0-9_\-]', '_'
    $safeName = $safeName -replace '_+', '_'
    return $safeName
}

$MsiExitCodes = @{
    0    = "SUCCESS - Installation completed successfully"
    1603 = "FATAL ERROR - Installation failed (check permissions or conflicting software)"
    1618 = "ALREADY IN PROGRESS - Another installation is running. Wait and try again"
    1619 = "PACKAGE NOT FOUND - The MSI file could not be opened"
    1620 = "INVALID PACKAGE - The MSI file is corrupt or invalid"
    1622 = "LOG FILE ERROR - Could not open the MSI log file"
    1625 = "BLOCKED BY POLICY - Installation is disabled by system policy"
    1638 = "NEWER VERSION EXISTS - A newer version of ScreenConnect is already installed"
    1641 = "SUCCESS (REBOOT REQUIRED) - Install succeeded but a reboot is needed"
    3010 = "SUCCESS (REBOOT REQUIRED) - Install succeeded but a reboot is needed"
}

try {
    # Setup directories
    if (-not (Test-Path "C:\temp")) { New-Item -Path "C:\temp" -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory -Force | Out-Null }

    Write-Log "Starting $AppName installation"
    Write-Log "Company: $CompanyName"
    Write-Log "Site: $SiteName"
    Write-Log "Token: $AgentToken"

    # Sanitize names for URL
    $SafeCompany = ConvertTo-UrlSafeName -Name $CompanyName
    $SafeSite = ConvertTo-UrlSafeName -Name $SiteName

    # Construct download URL
    $DownloadUrl = "https://prod.setup.itsupport247.net/windows/BareboneAgent/32/${SafeSite}-${SafeCompany}_Windows_OS_ITSPlatform_TKN${AgentToken}/MSI/setup"
    Write-Log "Download URL: $DownloadUrl"

    # Download MSI
    $MsiFileName = "${SafeSite}-${SafeCompany}_Windows_OS_ITSPlatform_TKN${AgentToken}.msi"
    $MsiPath = Join-Path -Path $TempPath -ChildPath $MsiFileName

    Write-Log "Downloading MSI to: $MsiPath"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -UseBasicParsing -MaximumRedirection 5

    if (-not (Test-Path $MsiPath)) {
        throw "MSI file not found after download: $MsiPath"
    }

    $MsiSize = (Get-Item $MsiPath).Length
    Write-Log "Downloaded MSI size: $MsiSize bytes"

    if ($MsiSize -lt 1000) {
        $Content = Get-Content -Path $MsiPath -Raw -ErrorAction SilentlyContinue
        Write-Log "ERROR: Downloaded file appears to be an error response: $Content"
        throw "Downloaded file is too small to be a valid MSI"
    }

    # Install
    Write-Log "Installing ScreenConnect agent..."
    $MsiLogFile = "C:\temp\screenconnect_msi.log"
    $Arguments = "/i `"$MsiPath`" ALLUSERS=1 /qn /norestart /log `"$MsiLogFile`""
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow

    $ExitCode = $Process.ExitCode
    $FriendlyMessage = if ($MsiExitCodes.ContainsKey($ExitCode)) { $MsiExitCodes[$ExitCode] } else { "UNKNOWN EXIT CODE ($ExitCode) - Check $MsiLogFile for details" }
    Write-Log "Result: $FriendlyMessage"

    # Cleanup
    Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue

    if ($ExitCode -eq 0 -or $ExitCode -eq 1641 -or $ExitCode -eq 3010) {
        Write-Log "Installation complete"
    } else {
        Write-Log "Installation FAILED - see $MsiLogFile for MSI details"
    }

    exit $ExitCode
}
catch {
    Write-Log "ERROR: $_"
    exit 1
}
