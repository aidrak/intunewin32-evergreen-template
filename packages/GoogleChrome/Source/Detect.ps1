#Requires -Version 5.1
<#
    .SYNOPSIS
        Detection script for Google Chrome.

    .DESCRIPTION
        Checks if Google Chrome is installed with the expected minimum version.
        Returns exit code 0 if detected, 1 if not detected.

    .NOTES
        Use as Intune detection script (Script type).
#>

$AppName = "Google Chrome"
$AppPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
# Update this version to match your deployment
$MinVersion = [version]"100.0.0.0"

try {
    if (Test-Path -Path $AppPath) {
        $FileVersion = [version](Get-Item -Path $AppPath).VersionInfo.FileVersion
        if ($FileVersion -ge $MinVersion) {
            Write-Output "$AppName $FileVersion detected"
            exit 0
        }
    }
    exit 1
}
catch {
    exit 1
}
