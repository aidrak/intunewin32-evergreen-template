#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Generic installation script for Evergreen-based Intune Win32 app deployments.

    .DESCRIPTION
        This script reads configuration from Install.json and performs the installation
        using the Evergreen PowerShell module. Supports MSI, EXE, and custom installers.

    .PARAMETER Path
        Path to the package directory containing Install.json and source files.

    .EXAMPLE
        .\Install.ps1
        Runs installation from current directory.

    .NOTES
        Author: Based on PSPackageFactory by Aaron Parker
        https://github.com/aaronparker/packagefactory
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [System.String] $Path = $PWD
)

begin {
    # Ensure running as 64-bit process
    if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        Write-Warning "Relaunching as 64-bit process..."
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
        $Process = Start-Process -FilePath "$env:SystemRoot\Sysnative\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        exit $Process.ExitCode
    }

    # Import shared module
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\install\Install.psm1"
    if (-not (Test-Path -Path $ModulePath)) {
        $ModulePath = Join-Path -Path $Path -ChildPath "Install.psm1"
    }
    if (Test-Path -Path $ModulePath) {
        Import-Module -Name $ModulePath -Force
    }
    else {
        throw "Install.psm1 not found"
    }

    # Setup logging
    $LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    $PackageName = Split-Path -Path $Path -Leaf
    $LogFile = Join-Path -Path $LogPath -ChildPath "$PackageName-Install.log"

    Write-LogFile -Message "========================================" -LogFile $LogFile
    Write-LogFile -Message "Starting installation: $PackageName" -LogFile $LogFile
    Write-LogFile -Message "Script path: $Path" -LogFile $LogFile
}

process {
    try {
        # Load configuration
        $ConfigPath = Join-Path -Path $Path -ChildPath "Install.json"
        $Config = Get-InstallConfig -Path $ConfigPath
        Write-LogFile -Message "Loaded configuration for: $($Config.PackageInformation.SetupFile)" -LogFile $LogFile

        # Get installer file
        $SetupFile = Join-Path -Path $Path -ChildPath $Config.PackageInformation.SetupFile
        if (-not (Test-Path -Path $SetupFile)) {
            # Try to find it in Source subdirectory
            $SetupFile = Get-ChildItem -Path $Path -Filter $Config.PackageInformation.SetupFile -Recurse |
                Select-Object -First 1 -ExpandProperty FullName
        }

        if (-not $SetupFile -or -not (Test-Path -Path $SetupFile)) {
            throw "Setup file not found: $($Config.PackageInformation.SetupFile)"
        }
        Write-LogFile -Message "Setup file: $SetupFile" -LogFile $LogFile

        # Pre-install tasks
        if ($Config.PreInstall) {
            Write-LogFile -Message "Running pre-install tasks..." -LogFile $LogFile

            # Stop processes
            if ($Config.PreInstall.StopProcess) {
                foreach ($ProcessName in $Config.PreInstall.StopProcess) {
                    Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
                    Write-LogFile -Message "Stopped process: $ProcessName" -LogFile $LogFile
                }
            }

            # Remove files/folders
            if ($Config.PreInstall.Remove) {
                $Config.PreInstall.Remove | Remove-Path
            }
        }

        # Build argument list with variable substitution
        $LogName = "$PackageName-$($Config.PackageInformation.Version)"
        $Arguments = $Config.InstallTasks.ArgumentList
        $Arguments = $Arguments -replace "#SetupFile", $SetupFile
        $Arguments = $Arguments -replace "#LogPath", $LogPath
        $Arguments = $Arguments -replace "#LogName", $LogName
        $Arguments = $Arguments -replace "#PWD", $Path

        # Execute installation
        Write-LogFile -Message "Setup type: $($Config.PackageInformation.SetupType)" -LogFile $LogFile
        Write-LogFile -Message "Arguments: $Arguments" -LogFile $LogFile

        switch ($Config.PackageInformation.SetupType) {
            "MSI" {
                $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            }
            "EXE" {
                $Process = Start-Process -FilePath $SetupFile -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            }
            default {
                $Process = Start-Process -FilePath $SetupFile -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            }
        }

        $ExitCode = $Process.ExitCode
        Write-LogFile -Message "Installation exit code: $ExitCode" -LogFile $LogFile

        # Handle wait time if specified
        if ($Config.InstallTasks.Wait) {
            Write-LogFile -Message "Waiting $($Config.InstallTasks.Wait) seconds..." -LogFile $LogFile
            Start-Sleep -Seconds $Config.InstallTasks.Wait
        }

        # Post-install tasks
        if ($Config.PostInstall) {
            Write-LogFile -Message "Running post-install tasks..." -LogFile $LogFile

            # Remove files/folders
            if ($Config.PostInstall.Remove) {
                foreach ($Item in $Config.PostInstall.Remove) {
                    if (Test-Path -Path $Item) {
                        Remove-Item -Path $Item -Recurse -Force -ErrorAction SilentlyContinue
                        Write-LogFile -Message "Removed: $Item" -LogFile $LogFile
                    }
                }
            }

            # Copy files
            if ($Config.PostInstall.CopyFile) {
                foreach ($Copy in $Config.PostInstall.CopyFile) {
                    $Source = Join-Path -Path $Path -ChildPath $Copy.Source
                    Copy-File -Source $Source -Destination $Copy.Destination
                }
            }

            # Run commands
            if ($Config.PostInstall.Run) {
                foreach ($Command in $Config.PostInstall.Run) {
                    try {
                        Write-LogFile -Message "Running: $Command" -LogFile $LogFile
                        Invoke-Expression -Command $Command
                    }
                    catch {
                        Write-LogFile -Message "Command failed: $_" -LogFile $LogFile -LogLevel 2
                    }
                }
            }
        }

        Write-LogFile -Message "Installation completed with exit code: $ExitCode" -LogFile $LogFile
        exit $ExitCode
    }
    catch {
        Write-LogFile -Message "Installation failed: $_" -LogFile $LogFile -LogLevel 3
        exit 1
    }
}
