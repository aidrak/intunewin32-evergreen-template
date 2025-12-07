#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Creates Intune Win32 packages (.intunewin) from source folders.

    .DESCRIPTION
        Uses the Microsoft Win32 Content Prep Tool to package applications
        for deployment via Microsoft Intune.

    .PARAMETER PackagePath
        Path to the packages directory.

    .PARAMETER AppName
        Specific application to package. If not specified, packages all.

    .PARAMETER OutputPath
        Output directory for .intunewin files. Defaults to 'output' folder.

    .EXAMPLE
        .\New-IntuneWin32Package.ps1
        Packages all applications.

    .EXAMPLE
        .\New-IntuneWin32Package.ps1 -AppName GoogleChrome
        Packages only Google Chrome.

    .NOTES
        Requires IntuneWinAppUtil.exe - download from:
        https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.String] $PackagePath = (Join-Path -Path $PSScriptRoot -ChildPath "..\packages"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("GoogleChrome", "AdobeAcrobatReaderDC", "AdobeAcrobatReaderDCMUIVDI")]
    [System.String] $AppName,

    [Parameter(Mandatory = $false)]
    [System.String] $OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "..\output"),

    [Parameter(Mandatory = $false)]
    [System.String] $IntuneWinAppUtil
)

begin {
    # Find IntuneWinAppUtil.exe
    if (-not $IntuneWinAppUtil) {
        $PossiblePaths = @(
            (Join-Path -Path $PSScriptRoot -ChildPath "IntuneWinAppUtil.exe"),
            (Join-Path -Path $PSScriptRoot -ChildPath "..\tools\IntuneWinAppUtil.exe"),
            "C:\Tools\IntuneWinAppUtil.exe",
            "$env:LOCALAPPDATA\IntuneWinAppUtil\IntuneWinAppUtil.exe"
        )

        foreach ($Path in $PossiblePaths) {
            if (Test-Path -Path $Path) {
                $IntuneWinAppUtil = $Path
                break
            }
        }
    }

    if (-not $IntuneWinAppUtil -or -not (Test-Path -Path $IntuneWinAppUtil)) {
        Write-Host @"
IntuneWinAppUtil.exe not found!

Please download from:
https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool

Place the executable in one of these locations:
- $PSScriptRoot\IntuneWinAppUtil.exe
- $PSScriptRoot\..\tools\IntuneWinAppUtil.exe
- C:\Tools\IntuneWinAppUtil.exe

Or specify the path using -IntuneWinAppUtil parameter.
"@ -ForegroundColor Red
        exit 1
    }

    Write-Host "Using IntuneWinAppUtil: $IntuneWinAppUtil" -ForegroundColor Gray

    # Create output directory
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
}

process {
    # Get packages to process
    if ($AppName) {
        $Packages = Get-ChildItem -Path $PackagePath -Directory | Where-Object { $_.Name -eq $AppName }
    }
    else {
        $Packages = Get-ChildItem -Path $PackagePath -Directory
    }

    foreach ($Package in $Packages) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Packaging: $($Package.Name)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan

        $SourcePath = Join-Path -Path $Package.FullName -ChildPath "Source"
        $AppJsonPath = Join-Path -Path $Package.FullName -ChildPath "App.json"

        # Validate source folder
        if (-not (Test-Path -Path $SourcePath)) {
            Write-Warning "Source folder not found: $SourcePath"
            continue
        }

        # Check for installer file
        $SetupFile = "Install.ps1"
        if (Test-Path -Path $AppJsonPath) {
            # Get setup file from App.json if available
            $AppJson = Get-Content -Path $AppJsonPath -Raw | ConvertFrom-Json
            # For Win32 packages, we use Install.ps1 as the entry point
        }

        $SetupFilePath = Join-Path -Path $SourcePath -ChildPath $SetupFile
        if (-not (Test-Path -Path $SetupFilePath)) {
            Write-Warning "Setup file not found: $SetupFilePath"
            continue
        }

        # Create .intunewin package
        Write-Host "Creating .intunewin package..." -ForegroundColor Yellow

        $Arguments = @(
            "-c", "`"$SourcePath`"",
            "-s", "`"$SetupFile`"",
            "-o", "`"$OutputPath`"",
            "-q"
        )

        $Process = Start-Process -FilePath $IntuneWinAppUtil -ArgumentList $Arguments -Wait -PassThru -NoNewWindow

        if ($Process.ExitCode -eq 0) {
            $OutputFile = Join-Path -Path $OutputPath -ChildPath "Install.intunewin"
            $FinalFile = Join-Path -Path $OutputPath -ChildPath "$($Package.Name).intunewin"

            if (Test-Path -Path $OutputFile) {
                Move-Item -Path $OutputFile -Destination $FinalFile -Force
                Write-Host "Created: $FinalFile" -ForegroundColor Green
            }
        }
        else {
            Write-Error "Failed to create package for $($Package.Name)"
        }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Packaging complete!" -ForegroundColor Green
    Write-Host "Output location: $OutputPath" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
}
