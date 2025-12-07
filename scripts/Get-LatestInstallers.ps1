#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Downloads the latest application installers using Evergreen.

    .DESCRIPTION
        Uses the Evergreen PowerShell module to download the latest versions of
        configured applications. Updates App.json and Install.json with version info.

    .PARAMETER PackagePath
        Path to the packages directory.

    .PARAMETER AppName
        Specific application to download. If not specified, downloads all.

    .EXAMPLE
        .\Get-LatestInstallers.ps1
        Downloads all configured applications.

    .EXAMPLE
        .\Get-LatestInstallers.ps1 -AppName GoogleChrome
        Downloads only Google Chrome.

    .NOTES
        Requires Evergreen module: Install-Module -Name Evergreen
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.String] $PackagePath = (Join-Path -Path $PSScriptRoot -ChildPath "..\packages"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("GoogleChrome", "AdobeAcrobatReaderDC", "AdobeAcrobatReaderDCMUIVDI")]
    [System.String] $AppName
)

begin {
    # Ensure Evergreen is installed
    if (-not (Get-Module -Name Evergreen -ListAvailable)) {
        Write-Host "Installing Evergreen module..." -ForegroundColor Yellow
        Install-Module -Name Evergreen -Force -Scope CurrentUser
    }
    Import-Module -Name Evergreen -Force

    # Application configurations
    $Applications = @{
        "GoogleChrome" = @{
            EvergreenApp = "GoogleChrome"
            Filter       = @{
                Architecture = "x64"
                Channel      = "stable"
                Type         = "msi"
            }
            FileName     = "googlechromestandaloneenterprise64.msi"
        }
        "AdobeAcrobatReaderDC" = @{
            EvergreenApp = "AdobeAcrobatReaderDC"
            Filter       = @{
                Architecture = "x64"
                Language     = "English"
            }
            FileName     = $null  # Use original filename
        }
        "AdobeAcrobatReaderDCMUIVDI" = @{
            EvergreenApp = "AdobeAcrobatReaderDC"
            Filter       = @{
                Architecture = "x64"
                Language     = "MUI"
            }
            FileName     = $null  # Use original filename
        }
    }
}

process {
    # Determine which apps to process
    if ($AppName) {
        $AppsToProcess = @{ $AppName = $Applications[$AppName] }
    }
    else {
        $AppsToProcess = $Applications
    }

    foreach ($App in $AppsToProcess.GetEnumerator()) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Processing: $($App.Key)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan

        $AppConfig = $App.Value
        $DestPath = Join-Path -Path $PackagePath -ChildPath "$($App.Key)\Source"

        try {
            # Get latest version info
            Write-Host "Getting latest version from Evergreen..." -ForegroundColor Yellow
            $EvergreenApp = Get-EvergreenApp -Name $AppConfig.EvergreenApp

            # Apply filters
            foreach ($FilterKey in $AppConfig.Filter.Keys) {
                $FilterValue = $AppConfig.Filter[$FilterKey]
                $EvergreenApp = $EvergreenApp | Where-Object { $_.$FilterKey -eq $FilterValue }
            }

            $LatestApp = $EvergreenApp | Select-Object -First 1

            if (-not $LatestApp) {
                Write-Warning "No matching application found for $($App.Key)"
                continue
            }

            Write-Host "Found version: $($LatestApp.Version)" -ForegroundColor Green
            Write-Host "Download URL: $($LatestApp.URI)" -ForegroundColor Gray

            # Download installer
            Write-Host "Downloading installer..." -ForegroundColor Yellow
            if (-not (Test-Path -Path $DestPath)) {
                New-Item -Path $DestPath -ItemType Directory -Force | Out-Null
            }

            $DownloadedFile = $LatestApp | Save-EvergreenApp -Path $DestPath

            # Rename file if specified
            if ($AppConfig.FileName -and $DownloadedFile) {
                $NewPath = Join-Path -Path $DestPath -ChildPath $AppConfig.FileName
                if ($DownloadedFile.FullName -ne $NewPath) {
                    Move-Item -Path $DownloadedFile.FullName -Destination $NewPath -Force
                    Write-Host "Renamed to: $($AppConfig.FileName)" -ForegroundColor Gray
                }
            }

            # Update App.json
            $AppJsonPath = Join-Path -Path $PackagePath -ChildPath "$($App.Key)\App.json"
            if (Test-Path -Path $AppJsonPath) {
                $AppJson = Get-Content -Path $AppJsonPath -Raw | ConvertFrom-Json
                $AppJson.PackageInformation.Version = $LatestApp.Version
                $AppJson.DetectionRule.Value = $LatestApp.Version

                # Update setup file name
                if ($AppConfig.FileName) {
                    $AppJson.PackageInformation.SetupFile = $AppConfig.FileName
                }
                elseif ($DownloadedFile) {
                    $AppJson.PackageInformation.SetupFile = $DownloadedFile.Name
                }

                $AppJson | ConvertTo-Json -Depth 10 | Set-Content -Path $AppJsonPath
                Write-Host "Updated App.json" -ForegroundColor Green
            }

            # Update Install.json
            $InstallJsonPath = Join-Path -Path $DestPath -ChildPath "Install.json"
            if (Test-Path -Path $InstallJsonPath) {
                $InstallJson = Get-Content -Path $InstallJsonPath -Raw | ConvertFrom-Json
                $InstallJson.PackageInformation.Version = $LatestApp.Version

                if ($AppConfig.FileName) {
                    $InstallJson.PackageInformation.SetupFile = $AppConfig.FileName
                }
                elseif ($DownloadedFile) {
                    $InstallJson.PackageInformation.SetupFile = $DownloadedFile.Name
                }

                $InstallJson | ConvertTo-Json -Depth 10 | Set-Content -Path $InstallJsonPath
                Write-Host "Updated Install.json" -ForegroundColor Green
            }

            Write-Host "Successfully downloaded $($App.Key) v$($LatestApp.Version)" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to process $($App.Key): $_"
        }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Download complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}
