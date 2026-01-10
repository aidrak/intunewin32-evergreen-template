#Requires -Version 5.1
<#
    .SYNOPSIS
        Install ConnectWise ScreenConnect Agent.

    .DESCRIPTION
        Downloads and installs the ScreenConnect/ConnectWise Control agent MSI at runtime
        using the provided Company, Site, and Token parameters.

    .PARAMETER CompanyName
        The company name as configured in ConnectWise Control (e.g., "SecurServ Implementations").

    .PARAMETER SiteName
        The site name as configured in ConnectWise Control (e.g., "SecurServ Implementations").

    .PARAMETER AgentToken
        The agent token UUID from ConnectWise Control (e.g., "b76dab9c-6457-486a-abf4-e60879e93fb6").

    .NOTES
        Deploy via Intune as Win32 app.
        Install command: powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1 -CompanyName "Company" -SiteName "Site" -AgentToken "token-uuid"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

    [Parameter(Mandatory = $true)]
    [string]$SiteName,

    [Parameter(Mandatory = $true)]
    [string]$AgentToken
)

$AppName = "ScreenConnect"
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

function ConvertTo-UrlSafeName {
    param([string]$Name)
    # Replace spaces with underscores, remove or replace problematic characters
    $safeName = $Name -replace '\s+', '_'
    # Remove characters that might cause URL issues (keep alphanumeric, underscore, hyphen)
    $safeName = $safeName -replace '[^a-zA-Z0-9_\-]', '_'
    # Collapse multiple underscores
    $safeName = $safeName -replace '_+', '_'
    return $safeName
}

try {
    # Setup directories
    if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory -Force | Out-Null }

    Write-Log "Starting $AppName installation"
    Write-Log "Company: $CompanyName"
    Write-Log "Site: $SiteName"
    Write-Log "Token: $AgentToken"

    # Sanitize names for URL
    $SafeCompany = ConvertTo-UrlSafeName -Name $CompanyName
    $SafeSite = ConvertTo-UrlSafeName -Name $SiteName

    Write-Log "Sanitized Company: $SafeCompany"
    Write-Log "Sanitized Site: $SafeSite"

    # Construct download URL
    # Pattern: https://prod.setup.itsupport247.net/windows/BareboneAgent/32/{Site}-{Company}_Windows_OS_ITSPlatform_TKN{Token}/MSI/setup
    $DownloadUrl = "https://prod.setup.itsupport247.net/windows/BareboneAgent/32/${SafeSite}-${SafeCompany}_Windows_OS_ITSPlatform_TKN${AgentToken}/MSI/setup"
    Write-Log "Download URL: $DownloadUrl"

    # Construct MSI filename
    $MsiFileName = "${SafeSite}-${SafeCompany}_Windows_OS_ITSPlatform_TKN${AgentToken}.msi"
    $MsiPath = Join-Path -Path $TempPath -ChildPath $MsiFileName

    Write-Log "Downloading MSI to: $MsiPath"

    # Download MSI - the URL returns a 307 redirect to S3
    # Using -MaximumRedirection to follow redirects
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -UseBasicParsing -MaximumRedirection 5
    }
    catch {
        Write-Log "ERROR: Failed to download MSI: $_"
        throw "Failed to download ScreenConnect MSI from $DownloadUrl"
    }

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

    # Install ScreenConnect
    Write-Log "Installing ScreenConnect agent..."
    $Arguments = "/i `"$MsiPath`" ALLUSERS=1 /qn /norestart /log `"$LogPath\$AppName-MSI.log`""
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
