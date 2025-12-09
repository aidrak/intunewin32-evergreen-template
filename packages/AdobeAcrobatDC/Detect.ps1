#Requires -Version 5.1
<#
    .SYNOPSIS
        Detection script for Adobe Acrobat DC Pro/Standard.

    .DESCRIPTION
        Checks if Adobe Acrobat DC Pro/Standard is installed.
        Outputs text and exits 0 if detected, exits 1 if not.

    .NOTES
        Use as Intune custom detection script.
#>

$Paths = @(
    "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
    "C:\Program Files (x86)\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
)

foreach ($Path in $Paths) {
    if (Test-Path -Path $Path) {
        $Version = (Get-Item -Path $Path).VersionInfo.FileVersion
        Write-Output "Adobe Acrobat DC $Version detected"
        exit 0
    }
}

exit 1
