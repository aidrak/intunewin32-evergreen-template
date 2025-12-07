#Requires -Version 5.1
<#
    .SYNOPSIS
        Detection script for Adobe Acrobat Reader DC.

    .DESCRIPTION
        Checks if Adobe Acrobat Reader DC is installed with the expected minimum version.
        Returns exit code 0 if detected, 1 if not detected.

    .NOTES
        Use as Intune detection script (Script type).
#>

$AppName = "Adobe Acrobat Reader DC"
$AppPaths = @(
    "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
    "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
)
# Update this version to match your deployment
$MinVersion = [version]"20.0.0.0"

try {
    foreach ($AppPath in $AppPaths) {
        if (Test-Path -Path $AppPath) {
            $FileVersion = [version](Get-Item -Path $AppPath).VersionInfo.FileVersion
            if ($FileVersion -ge $MinVersion) {
                Write-Output "$AppName $FileVersion detected"
                exit 0
            }
        }
    }
    exit 1
}
catch {
    exit 1
}
