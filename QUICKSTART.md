# IntuneWin Packaging on Ubuntu

## Setup (One-time)
```bash
pwsh
Install-Module -Name SvRooij.ContentPrep.Cmdlet -Scope CurrentUser -Force
```

## Create .intunewin Package
```powershell
New-IntuneWinPackage -SourcePath "<source_folder>" -SetupFile "<setup_file>" -DestinationPath "<output_folder>"
```

### Parameters
- **SourcePath**: Folder containing all app files to package
- **SetupFile**: Main installer file (relative to SourcePath or full name only)
- **DestinationPath**: Where to save the .intunewin file

### Example
```powershell
# Package an MSI installer
New-IntuneWinPackage -SourcePath "/home/user/apps/chrome" -SetupFile "chrome.msi" -DestinationPath "/home/user/output"

# Package a PowerShell script
New-IntuneWinPackage -SourcePath "/home/user/apps/script" -SetupFile "install.ps1" -DestinationPath "/home/user/output"
```

## Extract .intunewin Package (Optional)
```powershell
Unlock-IntuneWinPackage -SourceFile "<file.intunewin>" -DestinationPath "<extract_folder>"
```

## Notes
- Cross-platform replacement for IntuneWinAppUtil.exe
- Works natively on Linux with PowerShell Core
- Does NOT extract MSI metadata (ProductCode, etc.) - use Windows tool if needed
- Approximately 2x faster than official Microsoft tool