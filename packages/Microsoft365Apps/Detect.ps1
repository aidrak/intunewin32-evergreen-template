#Requires -Version 5.1
<#
.SYNOPSIS
    Detection script for Microsoft 365 Apps.

.DESCRIPTION
    Checks if Microsoft 365 Apps (any core Office app) is installed.
    Exit 0 = Installed, Exit 1 = Not installed
#>

# Check for Office installation via registry
$OfficePaths = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration"
)

foreach ($Path in $OfficePaths) {
    if (Test-Path $Path) {
        $VersionInfo = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
        if ($VersionInfo.VersionToReport) {
            Write-Host "Microsoft 365 Apps detected: $($VersionInfo.VersionToReport)"
            exit 0
        }
    }
}

# Alternative: Check for Office executables
$OfficeExePaths = @(
    "${env:ProgramFiles}\Microsoft Office\root\Office16\WINWORD.EXE",
    "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE"
)

foreach ($ExePath in $OfficeExePaths) {
    if (Test-Path $ExePath) {
        $Version = (Get-Item $ExePath).VersionInfo.ProductVersion
        Write-Host "Microsoft 365 Apps detected: $Version"
        exit 0
    }
}

# Not found
exit 1
