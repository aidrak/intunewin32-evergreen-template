# Build .intunewin Package

Build an Intune Win32 package from a package folder.

## Usage

When asked to build an .intunewin package, use this process:

## Build Command

The `SvRooij.ContentPrep.Cmdlet` module does not allow DestinationPath to be the same as or a subfolder of SourcePath. Use `/tmp` as an intermediate destination:

```bash
pwsh -Command "New-IntuneWinPackage -SourcePath 'packages/APPNAME' -SetupFile 'APPNAME.txt' -DestinationPath '/tmp'" && mv /tmp/APPNAME.intunewin packages/APPNAME/
```

Replace `APPNAME` with the actual package name (e.g., `SentinelOne`, `GoogleChrome`).

## Example

```bash
pwsh -Command "New-IntuneWinPackage -SourcePath 'packages/SentinelOne' -SetupFile 'SentinelOne.txt' -DestinationPath '/tmp'" && mv /tmp/SentinelOne.intunewin packages/SentinelOne/
```

## Package Structure

Each package folder must contain:
- `AppName.txt` - Empty dummy file (determines .intunewin output name)
- `Install.ps1` - Installation script
- `Uninstall.ps1` - Uninstallation script
- `Detect.ps1` - Detection script for Intune

## Notes

- The `-SetupFile` parameter determines the output filename (`.txt` → `.intunewin`)
- No renaming required - the module handles naming automatically
- Output is ~same size as source folder contents (compressed and encrypted)
