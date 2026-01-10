#Requires -Version 5.1
<#
    .SYNOPSIS
        Detect ConnectWise ScreenConnect Agent.

    .DESCRIPTION
        Checks if ScreenConnect Client is installed by searching the registry.
        The thumbprint (e6bb5af43151f034) is consistent across all ConnectWise Control installations.

    .NOTES
        Exit 0 = Installed (detection successful)
        Exit 1 = Not installed (detection failed)
#>

$Thumbprint = "e6bb5af43151f034"

# Registry paths to search
$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

try {
    $ScreenConnect = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*ScreenConnect Client*$Thumbprint*" } |
        Select-Object -First 1

    if ($ScreenConnect) {
        Write-Output "$($ScreenConnect.DisplayName) is installed"
        exit 0
    }
    else {
        Write-Output "ScreenConnect Client not detected"
        exit 1
    }
}
catch {
    Write-Output "Detection error: $_"
    exit 1
}
