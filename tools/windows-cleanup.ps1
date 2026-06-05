<#
.SYNOPSIS
    Windows cleanup helper for the PowerShell Toolkit

.DESCRIPTION
    Provides options to run Disk Cleanup (interactive) and DISM component cleanup with /ResetBase.
    Ensures the script runs elevated and writes logs to the temp toolkit folder.
#>

function Ensure-Elevated {
    $current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Administrator privileges are required. Attempting to restart elevated...' -ForegroundColor Yellow
        $psExe = (Get-Command powershell).Source
        if ($PSCommandPath) {
            Start-Process -FilePath $psExe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"" -Verb RunAs
        } else {
            Start-Process -FilePath $psExe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command','"Write-Host Elevated; Start-Sleep -Seconds 1"' -Verb RunAs
        }
        Exit
    }
}

function Get-ToolTemp {
    $tempRoot = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } else { [IO.Path]::GetTempPath() }
    $dir = Join-Path $tempRoot 'ps-toolkit-tools'
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
    return $dir
}

function Run-DiskCleanupInteractive {
    Write-Host 'Launching Disk Cleanup (interactive)...' -ForegroundColor Cyan
    Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/LOWDISK' -Wait
    Write-Host 'Disk Cleanup finished (interactive).' -ForegroundColor Green
}

function Run-DiskCleanupSageRun {
    param([string]$LogFile)
    Write-Host 'Running Disk Cleanup (sagerun:1)...' -ForegroundColor Cyan
    Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:1' -NoNewWindow -Wait
    Out-File -FilePath $LogFile -InputObject "Disk Cleanup (sagerun:1) executed at $(Get-Date)" -Append
    Write-Host "Disk Cleanup (sagerun) finished. Log: $LogFile" -ForegroundColor Green
}

function Run-DismResetBase {
    param([string]$LogFile)
    if (-not (Get-Command dism.exe -ErrorAction SilentlyContinue)) {
        Write-Host 'DISM not found on this system.' -ForegroundColor Red
        return
    }

    Write-Host 'Running: DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase' -ForegroundColor Cyan
    $args = '/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase'
    try {
        & 'dism.exe' @args 2>&1 | Tee-Object -FilePath $LogFile
        Write-Host "DISM ResetBase finished. Log: $LogFile" -ForegroundColor Green
    } catch {
        Write-Host "DISM ResetBase failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-Menu {
    Write-Host 'Windows Cleanup Options' -ForegroundColor Cyan
    Write-Host '[1] Disk Cleanup (interactive)' -ForegroundColor Green
    Write-Host '[2] Disk Cleanup (sagerun:1) (automated settings)' -ForegroundColor Green
    Write-Host '[3] DISM component cleanup + ResetBase' -ForegroundColor Green
    Write-Host '[4] Run Disk Cleanup (interactive) then DISM ResetBase' -ForegroundColor Green
    Write-Host '[0] Exit' -ForegroundColor Yellow
    $choice = Read-Host 'Select an option (0-4)'
    return $choice
}

Clear-Host
Ensure-Elevated

$toolTemp = Get-ToolTemp
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logFile = Join-Path $toolTemp "windows-cleanup-$timestamp.log"

while ($true) {
    $choice = Show-Menu
    switch ($choice) {
        '1' {
            Run-DiskCleanupInteractive
            break
        }
        '2' {
            Run-DiskCleanupSageRun -LogFile $logFile
            break
        }
        '3' {
            Run-DismResetBase -LogFile $logFile
            break
        }
        '4' {
            Run-DiskCleanupInteractive
            Run-DismResetBase -LogFile $logFile
            break
        }
        '0' {
            Write-Host 'Exiting.' -ForegroundColor Yellow
            break
        }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Red
        }
    }

    if ($choice -in '0','1','2','3','4') { break }
    Start-Sleep -Milliseconds 500
}

Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
Read-Host 'Press Enter to return'
