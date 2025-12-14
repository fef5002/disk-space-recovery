# disk-space-recovery

Triage Windows 10 local disk to free up space with an automated PowerShell script.

## Overview

This repository contains a PowerShell script that helps recover disk space on Windows 10 systems by cleaning:
- Temporary files (Windows and User temp folders)
- Windows Update cache
- Recycle Bin
- System logs and prefetch files

## Requirements

- Windows 10
- PowerShell 5.0 or higher
- Administrator privileges

## Installation

1. Clone or download this repository:
   ```bash
   git clone https://github.com/fef5002/disk-space-recovery.git
   cd disk-space-recovery
   ```

2. Ensure you can run PowerShell scripts. You may need to set the execution policy:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Run all cleanup operations (recommended)

Open PowerShell as Administrator and run:
```powershell
.\Recover-DiskSpace.ps1
```

### Analyze disk usage only (no cleanup)

```powershell
.\Recover-DiskSpace.ps1 -Operation Analyze
```

### Clean specific areas

Clean temporary files only:
```powershell
.\Recover-DiskSpace.ps1 -Operation TempFiles
```

Clean Windows Update cache:
```powershell
.\Recover-DiskSpace.ps1 -Operation WindowsUpdate
```

Empty Recycle Bin:
```powershell
.\Recover-DiskSpace.ps1 -Operation RecycleBin
```

Run Windows Disk Cleanup utility:
```powershell
.\Recover-DiskSpace.ps1 -Operation SystemCleanup
```

### Specify a different drive

Clean D: drive instead of C:
```powershell
.\Recover-DiskSpace.ps1 -DriveLetter D
```

## Features

- **Safe**: Only removes temporary and cache files that can be safely deleted
- **Informative**: Shows disk space before and after cleanup
- **Flexible**: Choose specific operations or run all at once
- **Analysis**: See what's taking up space before cleaning
- **Multi-drive**: Supports cleaning any drive letter

## What Gets Cleaned

| Area | Location | Safe to Clean |
|------|----------|---------------|
| Windows Temp | `C:\Windows\Temp` | ✅ Yes |
| User Temp | `%TEMP%` | ✅ Yes |
| Windows Update Cache | `C:\Windows\SoftwareDistribution\Download` | ✅ Yes |
| Recycle Bin | `C:\$Recycle.Bin` | ✅ Yes |
| System Logs | `C:\Windows\Logs` | ⚠️ Analyzed only |
| Prefetch | `C:\Windows\Prefetch` | ⚠️ Analyzed only |

## Safety Notes

- Always run with Administrator privileges
- The script will not delete personal files or program files
- A system restart may be required after cleanup
- Consider creating a system restore point before running major cleanups

## Troubleshooting

**Error: "This script must be run as Administrator!"**
- Right-click PowerShell and select "Run as Administrator"

**Error: "Cannot be loaded because running scripts is disabled"**
- Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Windows Update service fails to restart**
- Manually restart it: `Start-Service wuauserv`

## License

This project is provided as-is for personal and educational use.

## Contributing

Feel free to open issues or submit pull requests to improve the script.
