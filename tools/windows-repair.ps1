<#
.SYNOPSIS
	Windows repair helper for the PowerShell Toolkit

.DESCRIPTION
	Provides interactive options to run DISM /RestoreHealth and SFC /scannow.
	Ensures the script runs elevated and writes simple logs to the temp toolkit folder.
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

function Run-DismRestoreHealth {
	param([string]$LogFile)
	Write-Host 'Running: DISM /Online /Cleanup-Image /RestoreHealth' -ForegroundColor Cyan
	$args = '/Online','/Cleanup-Image','/RestoreHealth'
	try {
		$dismExe = Join-Path $env:windir 'System32\dism.exe'
		if (-not (Test-Path $dismExe)) { $dismExe = 'dism.exe' }

		# Prepare process start info to capture output as it is produced
		$psi = New-Object System.Diagnostics.ProcessStartInfo
		$psi.FileName = $dismExe
		$psi.Arguments = ($args -join ' ')
		$psi.RedirectStandardOutput = $true
		$psi.RedirectStandardError = $true
		$psi.UseShellExecute = $false
		$psi.CreateNoWindow = $true

		$proc = New-Object System.Diagnostics.Process
		$proc.StartInfo = $psi

		# Handlers append to logfile and write to host in real time
		$stdoutHandler = [System.Diagnostics.DataReceivedEventHandler]{ param($s,$e)
			if (-not [string]::IsNullOrEmpty($e.Data)) {
				[System.Console]::WriteLine($e.Data)
				[System.IO.File]::AppendAllText($LogFile, $e.Data + [System.Environment]::NewLine)
			}
		}
		$stderrHandler = [System.Diagnostics.DataReceivedEventHandler]{ param($s,$e)
			if (-not [string]::IsNullOrEmpty($e.Data)) {
				[System.Console]::WriteLine($e.Data)
				[System.IO.File]::AppendAllText($LogFile, $e.Data + [System.Environment]::NewLine)
			}
		}

		$proc.add_OutputDataReceived($stdoutHandler)
		$proc.add_ErrorDataReceived($stderrHandler)

		$proc.Start() | Out-Null
		$proc.BeginOutputReadLine()
		$proc.BeginErrorReadLine()
		$proc.WaitForExit()

		Write-Host "DISM finished. Log: $LogFile" -ForegroundColor Green
	} catch {
		Write-Host "DISM failed: $($_.Exception.Message)" -ForegroundColor Red
	}
}

function Run-SfcScan {
	param([string]$LogFile)
	Write-Host 'Running: sfc /scannow' -ForegroundColor Cyan
	$args = '/scannow'
	try {
		$sfcExe = Join-Path $env:windir 'System32\sfc.exe'
		if (-not (Test-Path $sfcExe)) { $sfcExe = 'sfc.exe' }
		$output = & $sfcExe $args 2>&1
		$output | Tee-Object -FilePath $LogFile
		Write-Host "SFC finished. Log: $LogFile" -ForegroundColor Green
	} catch {
		Write-Host "SFC failed: $($_.Exception.Message)" -ForegroundColor Red
	}
}

function Show-Menu {
	Write-Host 'Windows Repair Options' -ForegroundColor Cyan
	Write-Host '[1] Run DISM /RestoreHealth' -ForegroundColor Green
	Write-Host '[2] Run SFC /scannow' -ForegroundColor Green
	Write-Host '[3] Run DISM then SFC' -ForegroundColor Green
	Write-Host '[0] Exit' -ForegroundColor Yellow
	$choice = Read-Host 'Select an option (0-3)'
	return $choice
}

Clear-Host
Ensure-Elevated

$toolTemp = Get-ToolTemp
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logFile = Join-Path $toolTemp "windows-repair-$timestamp.log"

while ($true) {
	$choice = Show-Menu
	switch ($choice) {
		'1' {
			Run-DismRestoreHealth -LogFile $logFile
			break
		}
		'2' {
			Run-SfcScan -LogFile $logFile
			break
		}
		'3' {
			Run-DismRestoreHealth -LogFile $logFile
			Run-SfcScan -LogFile $logFile
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

	if ($choice -in '0','1','2','3') { break }
	Start-Sleep -Milliseconds 500
}

Write-Host "Log saved to: $logFile" -ForegroundColor Cyan
Read-Host 'Press Enter to return'

