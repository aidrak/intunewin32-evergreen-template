#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Microsoft 365 Apps using Office Deployment Tool with configurable options.

.DESCRIPTION
    Downloads ODT via Evergreen and installs Microsoft 365 Apps with dynamic configuration.
    Default: Full suite (Word, Excel, PowerPoint, OneNote, Outlook, Access, Publisher)
    without Shared Computer Licensing. Desktop shortcuts always published to Public Desktop.

.PARAMETER IncludeTeams
    Include Microsoft Teams (uses O365ProPlusRetail SKU instead of EEA NoTeams SKU)

.PARAMETER IncludeOneDrive
    Include OneDrive sync client

.PARAMETER SetSharedActivation
    Enable Shared Computer Licensing (for VDI/RDS/multi-user scenarios)

.EXAMPLE
    # Standard workstation (default)
    .\Install.ps1

.EXAMPLE
    # With Teams and OneDrive
    .\Install.ps1 -IncludeTeams -IncludeOneDrive

.EXAMPLE
    # VDI/RDS environment with shared licensing
    .\Install.ps1 -SetSharedActivation

.EXAMPLE
    # Full suite for VDI with Teams
    .\Install.ps1 -IncludeTeams -IncludeOneDrive -SetSharedActivation
#>

param(
    [switch]$IncludeTeams,
    [switch]$IncludeOneDrive,
    [switch]$SetSharedActivation
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
    Write-Host "  IncludeOneDrive: $IncludeOneDrive"
    Write-Host "  SharedComputerLicensing: $SetSharedActivation"
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

    if (-not $IncludeOneDrive) { $ExcludeApps += "OneDrive" }

    # Build ExcludeApp XML elements
    $ExcludeAppXml = ($ExcludeApps | ForEach-Object { "      <ExcludeApp ID=`"$_`" />" }) -join "`n"

    # Select Product ID based on Teams inclusion
    $ProductID = if ($IncludeTeams) { "O365ProPlusRetail" } else { "O365ProPlusEEANoTeamsRetail" }

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

        # Create scheduled task to create shortcuts after Office finishes installing
        Write-Host "Creating scheduled task for desktop shortcuts..." -ForegroundColor Yellow

        $TaskName = "M365Apps-CreateShortcuts"
        $ScriptPath = "C:\ProgramData\Intune\Scripts\M365Apps-CreateShortcuts.ps1"
        $ScriptDir = Split-Path $ScriptPath -Parent

        # Create script directory
        New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null

        # Build shortcut script with current parameters embedded
        $ShortcutScript = @"
# M365Apps-CreateShortcuts.ps1 - One-shot scheduled task script
`$LogFile = "C:\ProgramData\Intune\Logs\M365Apps-Shortcuts.log"
`$TaskName = "M365Apps-CreateShortcuts"
`$MaxAttempts = 60  # 60 attempts x 60 seconds = 60 minutes max wait
`$AttemptDelay = 60  # seconds

function Write-Log {
    param([string]`$Message)
    `$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path `$LogFile -Value "[`$Timestamp] `$Message" -ErrorAction SilentlyContinue
}

Write-Log "Shortcut creation task started"

`$OfficeRoot = "`$env:ProgramFiles\Microsoft Office\root\Office16"
`$WordExe = Join-Path `$OfficeRoot "WINWORD.EXE"

# Wait for Office to finish installing
`$Attempt = 0
while (-not (Test-Path `$WordExe) -and `$Attempt -lt `$MaxAttempts) {
    `$Attempt++
    Write-Log "Waiting for Office installation (attempt `$Attempt/`$MaxAttempts)..."
    Start-Sleep -Seconds `$AttemptDelay
}

if (-not (Test-Path `$WordExe)) {
    Write-Log "ERROR: Office installation not detected after `$MaxAttempts attempts. Exiting."
    Unregister-ScheduledTask -TaskName `$TaskName -Confirm:`$false -ErrorAction SilentlyContinue
    exit 1
}

Write-Log "Office installation detected. Creating shortcuts..."

`$PublicDesktop = "`$env:PUBLIC\Desktop"
`$WshShell = New-Object -ComObject WScript.Shell

# Core Office apps
`$OfficeApps = @{
    "Word"       = "WINWORD.EXE"
    "Excel"      = "EXCEL.EXE"
    "PowerPoint" = "POWERPNT.EXE"
    "OneNote"    = "ONENOTE.EXE"
    "Outlook"    = "OUTLOOK.EXE"
    "Access"     = "MSACCESS.EXE"
    "Publisher"  = "MSPUB.EXE"
}

foreach (`$App in `$OfficeApps.GetEnumerator()) {
    `$ExePath = Join-Path `$OfficeRoot `$App.Value
    if (Test-Path `$ExePath) {
        `$ShortcutPath = Join-Path `$PublicDesktop "`$(`$App.Key).lnk"
        `$Shortcut = `$WshShell.CreateShortcut(`$ShortcutPath)
        `$Shortcut.TargetPath = `$ExePath
        `$Shortcut.WorkingDirectory = `$OfficeRoot
        `$Shortcut.Save()
        Write-Log "Created: `$(`$App.Key).lnk"
    }
}

# OneDrive (if installed)
`$IncludeOneDrive = `$$($IncludeOneDrive.ToString().ToLower())
if (`$IncludeOneDrive) {
    `$OneDriveExe = "`$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe"
    if (Test-Path `$OneDriveExe) {
        `$ShortcutPath = Join-Path `$PublicDesktop "OneDrive.lnk"
        `$Shortcut = `$WshShell.CreateShortcut(`$ShortcutPath)
        `$Shortcut.TargetPath = `$OneDriveExe
        `$Shortcut.Save()
        Write-Log "Created: OneDrive.lnk"
    }
}

# Teams (if installed)
`$IncludeTeams = `$$($IncludeTeams.ToString().ToLower())
if (`$IncludeTeams) {
    `$TeamsExe = "`$env:ProgramFiles\WindowsApps\MSTeams_*\ms-teams.exe"
    `$TeamsPath = Get-Item `$TeamsExe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (`$TeamsPath) {
        `$ShortcutPath = Join-Path `$PublicDesktop "Microsoft Teams.lnk"
        `$Shortcut = `$WshShell.CreateShortcut(`$ShortcutPath)
        `$Shortcut.TargetPath = `$TeamsPath.FullName
        `$Shortcut.Save()
        Write-Log "Created: Microsoft Teams.lnk"
    }
}

Write-Log "Shortcut creation complete. Removing scheduled task."

# Clean up - remove the scheduled task and script
Unregister-ScheduledTask -TaskName `$TaskName -Confirm:`$false -ErrorAction SilentlyContinue
Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
"@

        # Save the script
        $ShortcutScript | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
        Write-Host "  Shortcut script saved to: $ScriptPath" -ForegroundColor Green

        # Create scheduled task - runs at startup with 2 minute delay
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        $Trigger.Delay = "PT2M"  # 2 minute delay after startup
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest -LogonType ServiceAccount
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Remove existing task if present
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

        # Register the task
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Creates Microsoft 365 Apps desktop shortcuts after installation completes" | Out-Null
        Write-Host "  Scheduled task '$TaskName' created" -ForegroundColor Green
        Write-Host "  Shortcuts will be created after next reboot (or when Office install completes)" -ForegroundColor Yellow

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
