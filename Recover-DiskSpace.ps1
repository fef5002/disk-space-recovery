#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows 10 Disk Space Recovery Tool
    
.DESCRIPTION
    This script performs various disk space recovery operations on Windows 10 systems.
    It cleans temporary files, Windows Update cache, recycle bin, and provides
    disk usage analysis to help free up space.
    
.PARAMETER Operation
    Specifies which cleanup operation to perform:
    - All: Perform all cleanup operations (default)
    - TempFiles: Clean temporary files
    - WindowsUpdate: Clean Windows Update cache
    - RecycleBin: Empty recycle bin
    - SystemCleanup: Run Windows Disk Cleanup
    - Analyze: Only analyze disk usage without cleaning
    
.PARAMETER DriveLetter
    Specifies the drive letter to clean (default: C)
    
.EXAMPLE
    .\Recover-DiskSpace.ps1
    Runs all cleanup operations on C: drive
    
.EXAMPLE
    .\Recover-DiskSpace.ps1 -Operation Analyze
    Analyzes disk usage without performing cleanup
    
.EXAMPLE
    .\Recover-DiskSpace.ps1 -Operation TempFiles -DriveLetter D
    Cleans temporary files on D: drive
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "TempFiles", "WindowsUpdate", "RecycleBin", "SystemCleanup", "Analyze")]
    [string]$Operation = "All",
    
    [Parameter(Mandatory=$false)]
    [ValidatePattern("^[A-Za-z]$")]
    [string]$DriveLetter = "C"
)

# Ensure we're running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator!"
    exit 1
}

$ErrorActionPreference = "Continue"
$drive = "$DriveLetter`:"

# Function to get folder size
function Get-FolderSize {
    param([string]$Path)
    
    if (Test-Path $Path) {
        try {
            $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            return [math]::Round($size / 1GB, 2)
        } catch {
            return 0
        }
    }
    return 0
}

# Function to format bytes to human readable
function Format-Bytes {
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes Bytes"
    }
}

# Function to display disk space info
function Show-DiskSpace {
    Write-Host "`n=== Disk Space Information ===" -ForegroundColor Cyan
    $diskInfo = Get-PSDrive $DriveLetter -ErrorAction SilentlyContinue
    if ($diskInfo) {
        $usedSpace = $diskInfo.Used
        $freeSpace = $diskInfo.Free
        $totalSpace = $usedSpace + $freeSpace
        $percentUsed = [math]::Round(($usedSpace / $totalSpace) * 100, 2)
        
        Write-Host "Drive: $drive"
        Write-Host "Total Space: $(Format-Bytes $totalSpace)"
        Write-Host "Used Space:  $(Format-Bytes $usedSpace) ($percentUsed%)"
        Write-Host "Free Space:  $(Format-Bytes $freeSpace)"
        Write-Host ""
    }
}

# Function to analyze disk usage
function Invoke-DiskAnalysis {
    Write-Host "`n=== Analyzing Disk Usage ===" -ForegroundColor Cyan
    
    $paths = @{
        "Windows Temp" = "$env:SystemRoot\Temp"
        "User Temp" = "$env:TEMP"
        "Recycle Bin" = "$drive\`$Recycle.Bin"
        "Windows Update" = "$env:SystemRoot\SoftwareDistribution\Download"
        "Windows Logs" = "$env:SystemRoot\Logs"
        "Prefetch" = "$env:SystemRoot\Prefetch"
    }
    
    $totalCleanable = 0
    foreach ($item in $paths.GetEnumerator()) {
        $size = Get-FolderSize -Path $item.Value
        if ($size -gt 0) {
            Write-Host "$($item.Key): $size GB" -ForegroundColor Yellow
            $totalCleanable += $size
        }
    }
    
    Write-Host "`nEstimated Cleanable Space: $totalCleanable GB" -ForegroundColor Green
}

# Function to clean temporary files
function Clear-TemporaryFiles {
    Write-Host "`n=== Cleaning Temporary Files ===" -ForegroundColor Cyan
    
    $tempPaths = @(
        "$env:SystemRoot\Temp\*",
        "$env:TEMP\*"
    )
    
    $freedSpace = 0
    foreach ($path in $tempPaths) {
        try {
            Write-Host "Cleaning: $path"
            $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            $freedSpace += $size
            Write-Host "  Freed: $(Format-Bytes $size)" -ForegroundColor Green
        } catch {
            Write-Warning "  Could not clean: $path"
        }
    }
    
    Write-Host "`nTotal freed from temp files: $(Format-Bytes $freedSpace)" -ForegroundColor Green
}

# Function to clean Windows Update cache
function Clear-WindowsUpdateCache {
    Write-Host "`n=== Cleaning Windows Update Cache ===" -ForegroundColor Cyan
    
    try {
        Write-Host "Stopping Windows Update service..."
        Stop-Service -Name wuauserv -Force -ErrorAction Stop
        
        $updatePath = "$env:SystemRoot\SoftwareDistribution\Download\*"
        Write-Host "Cleaning: $updatePath"
        
        $items = Get-ChildItem -Path $updatePath -Recurse -Force -ErrorAction SilentlyContinue
        $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        Remove-Item -Path $updatePath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "Starting Windows Update service..."
        Start-Service -Name wuauserv -ErrorAction Stop
        
        Write-Host "Freed: $(Format-Bytes $size)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not clean Windows Update cache: $_"
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }
}

# Function to empty recycle bin
function Clear-RecycleBinDrive {
    Write-Host "`n=== Emptying Recycle Bin ===" -ForegroundColor Cyan
    
    try {
        $recycleBinPath = "$drive\`$Recycle.Bin"
        $size = Get-FolderSize -Path $recycleBinPath
        
        Clear-RecycleBin -DriveLetter $DriveLetter -Force -ErrorAction Stop
        Write-Host "Emptied Recycle Bin on $drive - Freed: $size GB" -ForegroundColor Green
    } catch {
        Write-Warning "Could not empty Recycle Bin: $_"
    }
}

# Function to run Windows Disk Cleanup
function Invoke-SystemCleanup {
    Write-Host "`n=== Running Windows Disk Cleanup ===" -ForegroundColor Cyan
    
    try {
        Write-Host "Starting Disk Cleanup utility..."
        Write-Host "Note: This will open the Disk Cleanup dialog. Please configure and run it manually." -ForegroundColor Yellow
        
        # Run cleanmgr with sageset to prepare cleanup settings
        Start-Process cleanmgr.exe -ArgumentList "/d $DriveLetter" -Wait:$false
        
        Write-Host "Disk Cleanup utility started." -ForegroundColor Green
    } catch {
        Write-Warning "Could not start Disk Cleanup: $_"
    }
}

# Main execution
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "Windows 10 Disk Space Recovery Tool" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Show initial disk space
Show-DiskSpace

# Execute requested operation
switch ($Operation) {
    "Analyze" {
        Invoke-DiskAnalysis
    }
    "TempFiles" {
        Invoke-DiskAnalysis
        Clear-TemporaryFiles
    }
    "WindowsUpdate" {
        Invoke-DiskAnalysis
        Clear-WindowsUpdateCache
    }
    "RecycleBin" {
        Invoke-DiskAnalysis
        Clear-RecycleBinDrive
    }
    "SystemCleanup" {
        Invoke-DiskAnalysis
        Invoke-SystemCleanup
    }
    "All" {
        Invoke-DiskAnalysis
        Clear-TemporaryFiles
        Clear-WindowsUpdateCache
        Clear-RecycleBinDrive
        Write-Host "`nNote: Run with -Operation SystemCleanup for additional Windows cleanup options." -ForegroundColor Yellow
    }
}

# Show final disk space
Show-DiskSpace

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Green
Write-Host "Please restart your computer for all changes to take effect." -ForegroundColor Yellow
