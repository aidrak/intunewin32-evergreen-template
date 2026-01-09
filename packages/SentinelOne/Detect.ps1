#Requires -Version 5.1
<#
    .SYNOPSIS
        Detection script for SentinelOne EDR Agent.

    .DESCRIPTION
        Checks if SentinelOne is installed via registry key.
        Outputs text and exits 0 if detected, exits 1 if not.

    .NOTES
        Use as Intune custom detection script.
#>

# Registry-based detection (recommended)
$RegistryPath = "HKLM:\SOFTWARE\Sentinel Labs\Sentinel Agent"

if (Test-Path -Path $RegistryPath) {
    # Try to get version info
    $AgentInfo = Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue
    if ($AgentInfo.AgentVersion) {
        Write-Output "SentinelOne Agent $($AgentInfo.AgentVersion) detected"
    }
    else {
        Write-Output "SentinelOne Agent detected"
    }
    exit 0
}

# Fallback: Check for executable
$ExePath = "C:\Program Files\SentinelOne\Sentinel Agent\SentinelAgent.exe"
if (Test-Path -Path $ExePath) {
    $Version = (Get-Item -Path $ExePath).VersionInfo.FileVersion
    Write-Output "SentinelOne Agent $Version detected"
    exit 0
}

exit 1
