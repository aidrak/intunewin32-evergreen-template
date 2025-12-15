#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstalls Microsoft 365 Apps using Office Deployment Tool.

.DESCRIPTION
    Downloads ODT and removes all Microsoft 365 Apps from the system.
#>

$AppName = "Microsoft365Apps"
$LogPath = "C:\ProgramData\Intune\Logs"
$DownloadPath = "C:\ProgramData\Intune\Downloads\$AppName-Uninstall"
$LogFile = "$LogPath\$AppName-Uninstall.log"

# Create directories
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null

# Start logging
Start-Transcript -Path $LogFile -Append -Force

try {
    Write-Host "=== Microsoft 365 Apps Uninstallation ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""

    # Download ODT setup.exe from Microsoft
    Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Yellow
    $ODTUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
    $ODTPath = "$DownloadPath\setup.exe"
    Invoke-WebRequest -Uri $ODTUrl -OutFile $ODTPath -UseBasicParsing

    # Generate uninstall configuration XML
    $ConfigXml = @"
<Configuration>
  <Remove All="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@

    # Save configuration
    $ConfigPath = "$DownloadPath\uninstall.xml"
    $ConfigXml | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
    Write-Host "Uninstall configuration saved to: $ConfigPath" -ForegroundColor Green

    # Run ODT setup
    Write-Host "Starting Microsoft 365 Apps uninstallation..." -ForegroundColor Yellow
    $UninstallArgs = "/configure `"$ConfigPath`""
    $Process = Start-Process -FilePath $ODTPath -ArgumentList $UninstallArgs -Wait -PassThru -NoNewWindow

    if ($Process.ExitCode -eq 0) {
        Write-Host "Microsoft 365 Apps uninstalled successfully!" -ForegroundColor Green
    } else {
        Write-Host "Uninstallation completed with exit code: $($Process.ExitCode)" -ForegroundColor Yellow
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
