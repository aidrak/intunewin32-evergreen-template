#Requires -PSEdition Desktop
#Requires -Version 5.1
<#
    .SYNOPSIS
        Shared functions for Intune Win32 app installation scripts.

    .DESCRIPTION
        This module provides common functions used by Install.ps1 scripts for
        Evergreen-based application deployments via Microsoft Intune.
#>

function Write-LogFile {
    <#
        .SYNOPSIS
            Write to a log file in CMTrace format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [System.String] $Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [System.String] $LogFile = $(Join-Path -Path $PWD -ChildPath "Install.log"),

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet(1, 2, 3)]
        [System.Int16] $LogLevel = 1
    )

    begin {
        # Get calling function name
        $Component = (Get-PSCallStack)[1].Command
        if ([System.String]::IsNullOrEmpty($Component)) { $Component = "Install" }
    }

    process {
        # Build log entry
        $TimeGenerated = Get-Date -Format "HH:mm:ss.fffzzz"
        $DateGenerated = Get-Date -Format "MM-dd-yyyy"
        $LogLine = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
        $FormatArgs = @($Message, $TimeGenerated, $DateGenerated, $Component, $LogLevel)
        $LogEntry = $LogLine -f $FormatArgs

        # Write to log file
        try {
            Add-Content -Path $LogFile -Value $LogEntry -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

function Get-InstalledSoftware {
    <#
        .SYNOPSIS
            Retrieves installed software from the registry.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.String] $Name
    )

    $UninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $Software = Get-ItemProperty -Path $UninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and $null -eq $_.ParentKeyName }

    if ($Name) {
        $Software = $Software | Where-Object { $_.DisplayName -like "*$Name*" }
    }

    return $Software
}

function Get-InstallConfig {
    <#
        .SYNOPSIS
            Reads and parses the Install.json configuration file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [System.String] $Path = $(Join-Path -Path $PWD -ChildPath "Install.json")
    )

    if (Test-Path -Path $Path) {
        try {
            $Config = Get-Content -Path $Path -Raw | ConvertFrom-Json
            return $Config
        }
        catch {
            Write-LogFile -Message "Failed to parse Install.json: $_" -LogLevel 3
            throw $_
        }
    }
    else {
        throw "Install.json not found at: $Path"
    }
}

function Remove-Path {
    <#
        .SYNOPSIS
            Removes files or directories.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.String[]] $Path
    )

    process {
        foreach ($Item in $Path) {
            if (Test-Path -Path $Item) {
                if ($PSCmdlet.ShouldProcess($Item, "Remove")) {
                    try {
                        Remove-Item -Path $Item -Recurse -Force -ErrorAction Stop
                        Write-LogFile -Message "Removed: $Item"
                    }
                    catch {
                        Write-LogFile -Message "Failed to remove $Item`: $_" -LogLevel 2
                    }
                }
            }
        }
    }
}

function Copy-File {
    <#
        .SYNOPSIS
            Copies files with logging.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [System.String] $Source,

        [Parameter(Mandatory = $true)]
        [System.String] $Destination
    )

    if ($PSCmdlet.ShouldProcess($Destination, "Copy from $Source")) {
        try {
            $DestDir = Split-Path -Path $Destination -Parent
            if (-not (Test-Path -Path $DestDir)) {
                New-Item -Path $DestDir -ItemType Directory -Force | Out-Null
            }
            Copy-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
            Write-LogFile -Message "Copied: $Source -> $Destination"
        }
        catch {
            Write-LogFile -Message "Failed to copy file: $_" -LogLevel 3
            throw $_
        }
    }
}

function Stop-PathProcess {
    <#
        .SYNOPSIS
            Stops processes running from specified paths.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [System.String[]] $Path,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.SwitchParameter] $Force
    )

    foreach ($ProcessPath in $Path) {
        $Processes = Get-Process | Where-Object { $_.Path -like "*$ProcessPath*" }
        foreach ($Process in $Processes) {
            if ($PSCmdlet.ShouldProcess($Process.Name, "Stop")) {
                try {
                    if ($Force) {
                        $Process | Stop-Process -Force -ErrorAction Stop
                    }
                    else {
                        $Process | Stop-Process -ErrorAction Stop
                    }
                    Write-LogFile -Message "Stopped process: $($Process.Name)"
                }
                catch {
                    Write-LogFile -Message "Failed to stop process $($Process.Name): $_" -LogLevel 2
                }
            }
        }
    }
}

function Uninstall-Msi {
    <#
        .SYNOPSIS
            Uninstalls an MSI package by product code or name.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "ProductCode")]
        [System.String] $ProductCode,

        [Parameter(Mandatory = $true, ParameterSetName = "Name")]
        [System.String] $Name,

        [Parameter(Mandatory = $false)]
        [System.String] $LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    )

    if ($Name) {
        $Software = Get-InstalledSoftware -Name $Name | Where-Object { $_.UninstallString -like "*msiexec*" }
        if ($Software) {
            $ProductCode = $Software.PSChildName
        }
        else {
            Write-LogFile -Message "No MSI installation found for: $Name" -LogLevel 2
            return
        }
    }

    if ($ProductCode -and $PSCmdlet.ShouldProcess($ProductCode, "Uninstall MSI")) {
        $LogFile = Join-Path -Path $LogPath -ChildPath "Uninstall-$ProductCode.log"
        $Arguments = "/uninstall `"$ProductCode`" /quiet /norestart /log `"$LogFile`""

        Write-LogFile -Message "Uninstalling MSI: $ProductCode"
        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        Write-LogFile -Message "MSI uninstall exit code: $($Process.ExitCode)"
        return $Process.ExitCode
    }
}

function Save-Installer {
    <#
        .SYNOPSIS
            Downloads the latest installer using Evergreen.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.String] $AppName,

        [Parameter(Mandatory = $false)]
        [System.Collections.Hashtable] $Filter,

        [Parameter(Mandatory = $true)]
        [System.String] $Path
    )

    # Ensure Evergreen module is available
    if (-not (Get-Module -Name Evergreen -ListAvailable)) {
        Write-LogFile -Message "Installing Evergreen module..."
        Install-Module -Name Evergreen -Force -Scope CurrentUser
    }
    Import-Module -Name Evergreen -Force

    Write-LogFile -Message "Getting latest version info for: $AppName"
    $App = Get-EvergreenApp -Name $AppName

    # Apply filters if specified
    if ($Filter) {
        foreach ($Key in $Filter.Keys) {
            $App = $App | Where-Object { $_.$Key -eq $Filter[$Key] }
        }
    }

    # Get the first result
    $App = $App | Select-Object -First 1

    if ($App) {
        Write-LogFile -Message "Found version: $($App.Version)"
        Write-LogFile -Message "Downloading from: $($App.URI)"

        $FileName = Split-Path -Path $App.URI -Leaf
        $OutFile = Join-Path -Path $Path -ChildPath $FileName

        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }

        $App | Save-EvergreenApp -Path $Path

        return @{
            Version  = $App.Version
            FileName = $FileName
            Path     = $OutFile
        }
    }
    else {
        throw "No matching application found for: $AppName"
    }
}

Export-ModuleMember -Function *
