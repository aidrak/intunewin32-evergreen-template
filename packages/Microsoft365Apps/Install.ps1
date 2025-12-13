#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Microsoft 365 Apps using Office Deployment Tool with configurable options.

.DESCRIPTION
    Downloads ODT via Evergreen and installs Microsoft 365 Apps with dynamic configuration.
    Default: Minimal install (Word, Excel, PowerPoint, OneNote) with Shared Computer Licensing.

.PARAMETER IncludeTeams
    Include Microsoft Teams (uses O365ProPlusRetail SKU instead of EEA NoTeams SKU)

.PARAMETER IncludeOutlook
    Include classic Outlook

.PARAMETER IncludeOutlookNew
    Include new Outlook for Windows

.PARAMETER IncludeOneDrive
    Include OneDrive sync client

.PARAMETER IncludeAccess
    Include Microsoft Access

.PARAMETER IncludePublisher
    Include Microsoft Publisher

.PARAMETER NoSharedComputer
    Disable Shared Computer Licensing (for non-VDI/single-user scenarios)

.PARAMETER PublishDesktopShortcuts
    Create shortcuts on the Public Desktop for installed Office apps

.EXAMPLE
    # Minimal install (default)
    .\Install.ps1

.EXAMPLE
    # Full suite with Teams
    .\Install.ps1 -IncludeTeams -IncludeOutlook -IncludeOneDrive

.EXAMPLE
    # Standard workstation (not VDI)
    .\Install.ps1 -IncludeOutlook -IncludeOneDrive -NoSharedComputer
#>

param(
    [switch]$IncludeTeams,
    [switch]$IncludeOutlook,
    [switch]$IncludeOutlookNew,
    [switch]$IncludeOneDrive,
    [switch]$IncludeAccess,
    [switch]$IncludePublisher,
    [switch]$NoSharedComputer,
    [switch]$PublishDesktopShortcuts
)

$AppName = "Microsoft365Apps"
$LogPath = "C:\ProgramData\Intune\Logs"
$DownloadPath = "C:\ProgramData\Intune\Downloads\$AppName"
$LogFile = "$LogPath\$AppName-Install.log"

# Create directories
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null

# Start logging
Start-Transcript -Path $LogFile -Append -Force

try {
    Write-Host "=== Microsoft 365 Apps Installation ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""
    Write-Host "Configuration:"
    Write-Host "  IncludeTeams: $IncludeTeams"
    Write-Host "  IncludeOutlook: $IncludeOutlook"
    Write-Host "  IncludeOutlookNew: $IncludeOutlookNew"
    Write-Host "  IncludeOneDrive: $IncludeOneDrive"
    Write-Host "  IncludeAccess: $IncludeAccess"
    Write-Host "  IncludePublisher: $IncludePublisher"
    Write-Host "  SharedComputerLicensing: $(-not $NoSharedComputer)"
    Write-Host "  PublishDesktopShortcuts: $PublishDesktopShortcuts"
    Write-Host ""

    # Install Evergreen module
    Write-Host "Installing Evergreen module..." -ForegroundColor Yellow
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if (-not (Get-Module -Name Evergreen -ListAvailable)) {
        Install-Module -Name Evergreen -Force -Scope AllUsers
    }
    Import-Module Evergreen -Force
    Update-Evergreen -Force

    # Get Office Deployment Tool
    Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Yellow
    $ODT = Get-EvergreenApp -Name "Microsoft365Apps" | Where-Object { $_.Channel -eq "MonthlyEnterprise" } | Select-Object -First 1

    # Download ODT setup.exe from Microsoft
    $ODTUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
    $ODTPath = "$DownloadPath\setup.exe"
    Invoke-WebRequest -Uri $ODTUrl -OutFile $ODTPath -UseBasicParsing

    # Build ExcludeApp list
    $ExcludeApps = @("Lync", "Groove")  # Always exclude Skype for Business and Groove

    if (-not $IncludeOutlook) { $ExcludeApps += "Outlook" }
    if (-not $IncludeOutlookNew) { $ExcludeApps += "OutlookForWindows" }
    if (-not $IncludeOneDrive) { $ExcludeApps += "OneDrive" }
    if (-not $IncludeAccess) { $ExcludeApps += "Access" }
    if (-not $IncludePublisher) { $ExcludeApps += "Publisher" }

    # Build ExcludeApp XML elements
    $ExcludeAppXml = ($ExcludeApps | ForEach-Object { "      <ExcludeApp ID=`"$_`" />" }) -join "`n"

    # Select Product ID based on Teams inclusion
    $ProductID = if ($IncludeTeams) { "O365ProPlusRetail" } else { "O365ProPlusEEANoTeamsRetail" }

    # Shared Computer Licensing
    $SharedComputerValue = if ($NoSharedComputer) { "0" } else { "1" }

    # Generate configuration XML
    $ConfigXml = @"
<Configuration ID="intune-evergreen-$(Get-Date -Format 'yyyyMMddHHmmss')">
  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">
    <Product ID="$ProductID">
      <Language ID="en-us" />
$ExcludeAppXml
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="$SharedComputerValue" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <AppSettings>
    <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
    <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
    <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
  </AppSettings>
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@

    # Save configuration
    $ConfigPath = "$DownloadPath\configuration.xml"
    $ConfigXml | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
    Write-Host "Configuration XML saved to: $ConfigPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "--- Configuration XML Contents ---"
    Get-Content $ConfigPath
    Write-Host "--- End Configuration XML ---"
    Write-Host ""

    # Run ODT setup
    Write-Host "Starting Microsoft 365 Apps installation..." -ForegroundColor Yellow
    $InstallArgs = "/configure `"$ConfigPath`""
    $Process = Start-Process -FilePath $ODTPath -ArgumentList $InstallArgs -Wait -PassThru -NoNewWindow

    if ($Process.ExitCode -eq 0) {
        Write-Host "Microsoft 365 Apps installed successfully!" -ForegroundColor Green

        # Create desktop shortcuts if requested
        if ($PublishDesktopShortcuts) {
            Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow
            $PublicDesktop = "$env:PUBLIC\Desktop"
            $OfficeRoot = "$env:ProgramFiles\Microsoft Office\root\Office16"
            $WshShell = New-Object -ComObject WScript.Shell

            # Define apps and their executables
            $OfficeApps = @{
                "Word"       = @{ Exe = "WINWORD.EXE"; Include = $true }
                "Excel"      = @{ Exe = "EXCEL.EXE"; Include = $true }
                "PowerPoint" = @{ Exe = "POWERPNT.EXE"; Include = $true }
                "OneNote"    = @{ Exe = "ONENOTE.EXE"; Include = $true }
                "Outlook"    = @{ Exe = "OUTLOOK.EXE"; Include = $IncludeOutlook }
                "Access"     = @{ Exe = "MSACCESS.EXE"; Include = $IncludeAccess }
                "Publisher"  = @{ Exe = "MSPUB.EXE"; Include = $IncludePublisher }
            }

            foreach ($App in $OfficeApps.GetEnumerator()) {
                $ExePath = Join-Path $OfficeRoot $App.Value.Exe
                if ($App.Value.Include -and (Test-Path $ExePath)) {
                    $ShortcutPath = Join-Path $PublicDesktop "$($App.Key).lnk"
                    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
                    $Shortcut.TargetPath = $ExePath
                    $Shortcut.WorkingDirectory = $OfficeRoot
                    $Shortcut.Save()
                    Write-Host "  Created: $($App.Key).lnk" -ForegroundColor Green
                }
            }

            # Handle Teams separately (different install location)
            if ($IncludeTeams) {
                $TeamsExe = "$env:ProgramFiles\WindowsApps\MSTeams_*\ms-teams.exe"
                $TeamsPath = Get-Item $TeamsExe -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($TeamsPath) {
                    $ShortcutPath = Join-Path $PublicDesktop "Microsoft Teams.lnk"
                    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
                    $Shortcut.TargetPath = $TeamsPath.FullName
                    $Shortcut.Save()
                    Write-Host "  Created: Microsoft Teams.lnk" -ForegroundColor Green
                }
            }
        }
    } else {
        Write-Host "Installation completed with exit code: $($Process.ExitCode)" -ForegroundColor Yellow
    }

    # Cleanup
    Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Path $DownloadPath -Recurse -Force -ErrorAction SilentlyContinue

    Stop-Transcript
    exit $Process.ExitCode

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Transcript
    exit 1
}
