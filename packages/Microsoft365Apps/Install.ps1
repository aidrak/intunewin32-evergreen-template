#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Microsoft 365 Apps using Office Deployment Tool with configurable options.

.DESCRIPTION
    Downloads ODT directly from Microsoft CDN and installs Microsoft 365 Apps with dynamic configuration.
    Default: Full suite (Word, Excel, PowerPoint, OneNote, Outlook, Access, Publisher, Teams, OneDrive)
    without Shared Computer Licensing. Desktop shortcuts published to Public Desktop.
    Any app can be excluded using the -Exclude* parameters.

.PARAMETER ExcludeTeams
    Exclude Microsoft Teams

.PARAMETER ExcludeOneDrive
    Exclude OneDrive sync client

.PARAMETER SetSharedActivation
    Enable Shared Computer Licensing (for VDI/RDS/multi-user scenarios)

.PARAMETER ExcludeNewOutlook
    Exclude the new Outlook app (installs only classic Outlook)

.PARAMETER ExcludeWord
    Exclude Microsoft Word

.PARAMETER ExcludeExcel
    Exclude Microsoft Excel

.PARAMETER ExcludePowerPoint
    Exclude Microsoft PowerPoint

.PARAMETER ExcludeOneNote
    Exclude Microsoft OneNote

.PARAMETER ExcludeOutlook
    Exclude Microsoft Outlook (both classic and new)

.PARAMETER ExcludeAccess
    Exclude Microsoft Access

.PARAMETER ExcludePublisher
    Exclude Microsoft Publisher

.PARAMETER SkipShortcuts
    Skip creating desktop shortcuts for Office apps

.EXAMPLE
    # Full suite install (default) - includes Teams, OneDrive, and all Office apps
    .\Install.ps1

.EXAMPLE
    # VDI/RDS environment with shared licensing
    .\Install.ps1 -SetSharedActivation

.EXAMPLE
    # Exclude Teams and OneDrive
    .\Install.ps1 -ExcludeTeams -ExcludeOneDrive

.EXAMPLE
    # Minimal install: Word, Excel, Outlook only
    .\Install.ps1 -ExcludeTeams -ExcludeOneDrive -ExcludePowerPoint -ExcludeOneNote -ExcludeAccess -ExcludePublisher

.EXAMPLE
    # No desktop shortcuts
    .\Install.ps1 -SkipShortcuts
#>

param(
    [switch]$ExcludeTeams,
    [switch]$ExcludeOneDrive,
    [switch]$SetSharedActivation,
    [switch]$ExcludeNewOutlook,
    [switch]$ExcludeWord,
    [switch]$ExcludeExcel,
    [switch]$ExcludePowerPoint,
    [switch]$ExcludeOneNote,
    [switch]$ExcludeOutlook,
    [switch]$ExcludeAccess,
    [switch]$ExcludePublisher,
    [switch]$SkipShortcuts
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
    Write-Host "  ExcludeTeams: $ExcludeTeams"
    Write-Host "  ExcludeOneDrive: $ExcludeOneDrive"
    Write-Host "  ExcludeWord: $ExcludeWord"
    Write-Host "  ExcludeExcel: $ExcludeExcel"
    Write-Host "  ExcludePowerPoint: $ExcludePowerPoint"
    Write-Host "  ExcludeOneNote: $ExcludeOneNote"
    Write-Host "  ExcludeOutlook: $ExcludeOutlook"
    Write-Host "  ExcludeAccess: $ExcludeAccess"
    Write-Host "  ExcludePublisher: $ExcludePublisher"
    Write-Host "  ExcludeNewOutlook: $ExcludeNewOutlook"
    Write-Host "  SharedComputerLicensing: $SetSharedActivation"
    Write-Host "  SkipShortcuts: $SkipShortcuts"
    Write-Host ""

    # Download Office Deployment Tool
    Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Yellow
    $ODTUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
    $ODTPath = "$DownloadPath\setup.exe"
    Invoke-WebRequest -Uri $ODTUrl -OutFile $ODTPath -UseBasicParsing

    # Build ExcludeApp list
    $ExcludeApps = @("Lync", "Groove")  # Always exclude Skype for Business and Groove

    if ($ExcludeTeams) { $ExcludeApps += "Teams" }
    if ($ExcludeOneDrive) { $ExcludeApps += "OneDrive" }
    if ($ExcludeNewOutlook) { $ExcludeApps += "OutlookNew" }
    if ($ExcludeWord) { $ExcludeApps += "Word" }
    if ($ExcludeExcel) { $ExcludeApps += "Excel" }
    if ($ExcludePowerPoint) { $ExcludeApps += "PowerPoint" }
    if ($ExcludeOneNote) { $ExcludeApps += "OneNote" }
    if ($ExcludeOutlook) { $ExcludeApps += "Outlook" }
    if ($ExcludeAccess) { $ExcludeApps += "Access" }
    if ($ExcludePublisher) { $ExcludeApps += "Publisher" }

    # Build ExcludeApp XML elements
    $ExcludeAppXml = ($ExcludeApps | ForEach-Object { "      <ExcludeApp ID=`"$_`" />" }) -join "`n"

    # Product ID - always use O365ProPlusRetail, control apps via ExcludeApp
    $ProductID = "O365ProPlusRetail"

    # Shared Computer Licensing
    $SharedComputerValue = if ($SetSharedActivation) { "1" } else { "0" }

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
        Write-Host "Microsoft 365 Apps installation initiated successfully!" -ForegroundColor Green
        Write-Host ""

        # Wait for Office Click-to-Run to complete installation
        Write-Host "Waiting for Office Click-to-Run installation to complete..." -ForegroundColor Yellow
        $MaxAttempts = 120  # 120 attempts x 30 seconds = 60 minutes max wait
        $AttemptDelay = 30  # seconds
        $Attempt = 0
        $InstallComplete = $false
        $OfficeRoot = $null

        # Hardcoded paths where Word can be installed (avoids 32/64-bit registry issues)
        $WordPaths = @(
            "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
            "C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE"
        )

        while ($Attempt -lt $MaxAttempts -and -not $InstallComplete) {
            $Attempt++

            # Check each possible Word location
            foreach ($WordPath in $WordPaths) {
                if (Test-Path $WordPath) {
                    $OfficeRoot = Split-Path $WordPath -Parent
                    Write-Host "  Office installation complete! Found Word at: $WordPath" -ForegroundColor Green
                    $InstallComplete = $true
                    break
                }
            }

            if (-not $InstallComplete) {
                Write-Host "  Attempt $Attempt/$MaxAttempts - Waiting for Office installation..."
                Start-Sleep -Seconds $AttemptDelay
            }
        }

        if (-not $InstallComplete) {
            Write-Host "WARNING: Office installation may not have completed within timeout period" -ForegroundColor Yellow
            $OfficeRoot = "C:\Program Files\Microsoft Office\root\Office16"
        }

        # Remove Teams if -ExcludeTeams was specified (ODT doesn't reliably exclude new MSIX Teams)
        if ($ExcludeTeams) {
            Write-Host ""
            Write-Host "Removing Microsoft Teams (MSIX)..." -ForegroundColor Yellow

            # Remove provisioned package (prevents install for new users)
            $TeamsProvisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*MSTeams*" }
            if ($TeamsProvisioned) {
                $TeamsProvisioned | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                Write-Host "  Removed provisioned Teams package" -ForegroundColor Green
            }

            # Remove installed instances for all users
            $TeamsInstalled = Get-AppxPackage -AllUsers -Name "*MSTeams*" -ErrorAction SilentlyContinue
            if ($TeamsInstalled) {
                $TeamsInstalled | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Write-Host "  Removed installed Teams instances" -ForegroundColor Green
            }

            if (-not $TeamsProvisioned -and -not $TeamsInstalled) {
                Write-Host "  Teams was not found (already removed or not installed)" -ForegroundColor Green
            }
        }

        # Remove New Outlook if -ExcludeNewOutlook was specified (ODT doesn't reliably exclude it)
        if ($ExcludeNewOutlook) {
            Write-Host ""
            Write-Host "Removing New Outlook (OutlookForWindows)..." -ForegroundColor Yellow

            # Remove provisioned package (prevents install for new users)
            $OutlookProvisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*OutlookForWindows*" }
            if ($OutlookProvisioned) {
                $OutlookProvisioned | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                Write-Host "  Removed provisioned New Outlook package" -ForegroundColor Green
            }

            # Remove installed instances for all users
            $OutlookInstalled = Get-AppxPackage -AllUsers -Name "*OutlookForWindows*" -ErrorAction SilentlyContinue
            if ($OutlookInstalled) {
                $OutlookInstalled | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Write-Host "  Removed installed New Outlook instances" -ForegroundColor Green
            }

            if (-not $OutlookProvisioned -and -not $OutlookInstalled) {
                Write-Host "  New Outlook was not found (already removed or not installed)" -ForegroundColor Green
            }
        }

        # Create desktop shortcuts
        if (-not $SkipShortcuts) {
            Write-Host ""
            Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow

            $PublicDesktop = "$env:PUBLIC\Desktop"
            $WshShell = New-Object -ComObject WScript.Shell

            # Core Office apps - only create shortcuts for apps that weren't excluded
            $OfficeApps = @{}
            if (-not $ExcludeWord) { $OfficeApps["Word"] = "WINWORD.EXE" }
            if (-not $ExcludeExcel) { $OfficeApps["Excel"] = "EXCEL.EXE" }
            if (-not $ExcludePowerPoint) { $OfficeApps["PowerPoint"] = "POWERPNT.EXE" }
            if (-not $ExcludeOneNote) { $OfficeApps["OneNote"] = "ONENOTE.EXE" }
            if (-not $ExcludeOutlook) { $OfficeApps["Outlook"] = "OUTLOOK.EXE" }
            if (-not $ExcludeAccess) { $OfficeApps["Access"] = "MSACCESS.EXE" }
            if (-not $ExcludePublisher) { $OfficeApps["Publisher"] = "MSPUB.EXE" }

            foreach ($App in $OfficeApps.GetEnumerator()) {
                $ExePath = Join-Path $OfficeRoot $App.Value
                if (Test-Path $ExePath) {
                    $ShortcutPath = Join-Path $PublicDesktop "$($App.Key).lnk"
                    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
                    $Shortcut.TargetPath = $ExePath
                    $Shortcut.WorkingDirectory = $OfficeRoot
                    $Shortcut.Save()
                    Write-Host "  Created: $($App.Key).lnk" -ForegroundColor Green
                } else {
                    Write-Host "  Skipped: $($App.Key) (not found)" -ForegroundColor Yellow
                }
            }

            # OneDrive shortcut (if not excluded)
            if (-not $ExcludeOneDrive) {
                $OneDriveExe = "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
                if (Test-Path $OneDriveExe) {
                    $ShortcutPath = Join-Path $PublicDesktop "OneDrive.lnk"
                    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
                    $Shortcut.TargetPath = $OneDriveExe
                    $Shortcut.Save()
                    Write-Host "  Created: OneDrive.lnk" -ForegroundColor Green
                }
            }

            # Teams shortcut (if not excluded)
            if (-not $ExcludeTeams) {
                $TeamsExe = "C:\Program Files\WindowsApps\MSTeams_*\ms-teams.exe"
                $TeamsPath = Get-Item $TeamsExe -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($TeamsPath) {
                    $ShortcutPath = Join-Path $PublicDesktop "Microsoft Teams.lnk"
                    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
                    $Shortcut.TargetPath = $TeamsPath.FullName
                    $Shortcut.Save()
                    Write-Host "  Created: Microsoft Teams.lnk" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "Skipping desktop shortcut creation (-SkipShortcuts specified)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Installation complete. Signaling reboot required (exit code 1641)." -ForegroundColor Cyan

    } else {
        Write-Host "Installation failed with exit code: $($Process.ExitCode)" -ForegroundColor Red
        Stop-Transcript
        exit $Process.ExitCode
    }

    # Cleanup
    Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
    Remove-Item -Path $DownloadPath -Recurse -Force -ErrorAction SilentlyContinue

    Stop-Transcript

    # Exit with 1641 to signal Intune that a hard reboot is required
    # Intune will display a countdown dialog and force restart after grace period (default 120 min)
    exit 1641

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Transcript
    exit 1
}
