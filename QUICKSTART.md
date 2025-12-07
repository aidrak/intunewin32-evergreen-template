# Quick Start: Deploy to Intune

Pre-built packages that automatically install the latest version from the vendor.

## Step 1: Download

Download the `.intunewin` file from the `output/` folder:
- `GoogleChrome.intunewin`
- `AdobeAcrobatReaderDC.intunewin`
- `AdobeAcrobatReaderDCMUIVDI.intunewin` (for Citrix/AVD/RDS)

## Step 2: Upload to Intune

1. Go to [intune.microsoft.com](https://intune.microsoft.com)
2. Navigate to **Apps** → **All apps** → **Add**
3. Select **Windows app (Win32)** → **Select**
4. Click **Select app package file** and upload the `.intunewin` file

## Step 3: Configure App Information

| Field | Google Chrome | Adobe Reader DC |
|-------|---------------|-----------------|
| **Name** | Google Chrome | Adobe Acrobat Reader DC |
| **Publisher** | Google LLC | Adobe Inc. |

## Step 4: Configure Program

| Setting | Value |
|---------|-------|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| **Install behavior** | System |
| **Device restart behavior** | No specific action |

## Step 5: Configure Requirements

| Setting | Value |
|---------|-------|
| **Operating system architecture** | 64-bit |
| **Minimum operating system** | Windows 10 1809 |

## Step 6: Configure Detection Rules

| Setting | Value |
|---------|-------|
| **Rules format** | Manually configure detection rules |
| **Rule type** | File |

### Google Chrome
| Setting | Value |
|---------|-------|
| **Path** | `C:\Program Files\Google\Chrome\Application` |
| **File** | `chrome.exe` |
| **Detection method** | File or folder exists |

### Adobe Acrobat Reader DC
| Setting | Value |
|---------|-------|
| **Path** | `C:\Program Files\Adobe\Acrobat DC\Acrobat` |
| **File** | `Acrobat.exe` |
| **Detection method** | File or folder exists |

## Step 7: Assign

1. Click **Next** through Dependencies and Supersedence
2. Under **Assignments**, add your target groups:
   - **Required** = Auto-install
   - **Available** = User can install from Company Portal
3. Click **Create**

## Done

The app will deploy and always install the latest version from the vendor at install time.

---

## Requirements

Endpoints need internet access to:
- `powershellgallery.com` (Evergreen module)
- `dl.google.com` (Chrome)
- `ardownload2.adobe.com` (Adobe Reader)
