<#
.SYNOPSIS
	Windows activation helper for the PowerShell Toolkit

.DESCRIPTION
	Downloads and runs the activation helper from a public URL. Provides elevation,
	temporary caching, and logging similar to other toolkit scripts.
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

function Download-ScriptToTemp {
	param(
		[Parameter(Mandatory=$true)][string]$Url,
		[Parameter(Mandatory=$false)][string]$FileName
	)
	$toolTemp = Get-ToolTemp
	$fileName = if ($FileName) { $FileName } else { [IO.Path]::GetFileName($Url) }
	$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
	$localPath = Join-Path $toolTemp "$timestamp-$fileName"
	try {
		Write-Host "Downloading activation script to $localPath" -ForegroundColor Cyan
		Invoke-WebRequest -Uri $Url -OutFile $localPath -UseBasicParsing -ErrorAction Stop
		return $localPath
	} catch {
		Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
		return $null
	}
}

function Run-DownloadedScript {
	param(
		[Parameter(Mandatory=$true)][string]$ScriptPath
	)
	$toolTemp = Get-ToolTemp
	$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
	$logFile = Join-Path $toolTemp "activation-$timestamp.log"

	Write-Host "Executing activation script: $ScriptPath" -ForegroundColor Cyan
	$psExe = (Get-Command powershell).Source
	$args = '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$ScriptPath`""
	try {
		& $psExe @args 2>&1 | Tee-Object -FilePath $logFile
		Write-Host "Activation run finished. Log saved to: $logFile" -ForegroundColor Green
	} catch {
		Write-Host "Activation run failed: $($_.Exception.Message)" -ForegroundColor Red
	}
}

function Show-Menu {
	Write-Host 'Windows Activation Options' -ForegroundColor Cyan
	Write-Host '[1] Download and run activation script (recommended)' -ForegroundColor Green
	Write-Host '[2] Download activation script only (saved to temp)' -ForegroundColor Green
	Write-Host '[3] Run remote script inline (irm | iex) (not recommended)' -ForegroundColor Yellow
	Write-Host '[0] Exit' -ForegroundColor Yellow
	$choice = Read-Host 'Select an option (0-3)'
	return $choice
}

Clear-Host
Ensure-Elevated

$remoteUrl = 'https://get.activated.win'

while ($true) {
	$choice = Show-Menu
	switch ($choice) {
		'1' {
			$local = Download-ScriptToTemp -Url $remoteUrl -FileName 'activated.ps1'
			if ($local) { Run-DownloadedScript -ScriptPath $local }
			break
		}
		'2' {
			$local = Download-ScriptToTemp -Url $remoteUrl -FileName 'activated.ps1'
			if ($local) { Write-Host "Script saved to: $local" -ForegroundColor Cyan }
			break
		}
		'3' {
			Write-Host 'Running remote script inline (irm | iex)...' -ForegroundColor Yellow
			try { irm $remoteUrl | iex } catch { Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red }
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

Read-Host 'Press Enter to return'
