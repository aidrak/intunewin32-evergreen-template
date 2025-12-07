#Requires -Version 5.1
<#
    .SYNOPSIS
        Detection script for Google Chrome.

    .DESCRIPTION
        Checks if Google Chrome is installed.
        Outputs text and exits 0 if detected, exits 1 if not.

    .NOTES
        Use as Intune custom detection script.
#>

$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

if (Test-Path -Path $ChromePath) {
    $Version = (Get-Item -Path $ChromePath).VersionInfo.FileVersion
    Write-Output "Google Chrome $Version detected"
    exit 0
}

exit 1
