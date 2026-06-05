<#
.SYNOPSIS
    This script helps system administrators to perform powershell tasks efficiently.

.DESCRIPTION
    This script is the core of the toolkit. It provides the main functionality and serves as the entry point for the toolkit.
#>

# Changelog:
# 2026-06-05: Initial version. - robin.schmid@leuchterag.ch


# Parameters



# Functions
function Get-ToolDirectory {
    $tempRoot = if ($env:TEMP) { $env:TEMP } elseif ($env:TMP) { $env:TMP } else { [IO.Path]::GetTempPath() }
    return Join-Path $tempRoot 'ps-toolkit-tools'
}

function Download-FileWithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$Destination,
        [string]$Activity = 'Downloading tool'
    )

    $request = [System.Net.WebRequest]::Create($Uri)
    $request.Method = 'GET'
    $request.UserAgent = 'PowerShell Toolkit'
    $response = $request.GetResponse()
    $stream = $response.GetResponseStream()
    $fileStream = [System.IO.File]::Create($Destination)

    try {
        $buffer = New-Object byte[] 8192
        $totalBytes = $response.ContentLength
        $readBytes = 0
        $lastPercent = -1

        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $readBytes += $bytesRead

            if ($totalBytes -gt 0) {
                $percentComplete = [int](($readBytes / $totalBytes) * 100)
                $currentOperation = "$readBytes of $totalBytes bytes"
            } else {
                $percentComplete = 0
                $currentOperation = "$readBytes bytes downloaded"
            }

            if ($percentComplete -ne $lastPercent -or $totalBytes -le 0) {
                $lastPercent = $percentComplete
                Write-Progress -Activity $Activity -Status "Downloading $([System.IO.Path]::GetFileName($Destination))" -PercentComplete $percentComplete -CurrentOperation $currentOperation
            }
        }

        Write-Progress -Activity $Activity -Completed
    } finally {
        $fileStream.Close()
        $stream.Close()
        $response.Close()
    }
}

function Get-Tools {
    param(
        [string]$GitHubRepoUrl = 'https://github.com/Robinski07/ps-toolkit',
        [string]$RemoteToolsFolder = 'tools'
    )

    $toolDirectory = Get-ToolDirectory
    if (-not (Test-Path -Path $toolDirectory)) {
        New-Item -Path $toolDirectory -ItemType Directory | Out-Null
    }

    $repoPath = $GitHubRepoUrl.TrimEnd('/') -replace '^https?://github\.com/', ''
    if ($repoPath -notmatch '^[^/]+/[^/]+$') {
        Write-Warning "Invalid GitHub repository URL: $GitHubRepoUrl"
        return Get-ChildItem -Path $toolDirectory -Filter '*.ps1' | Sort-Object Name
    }

    $apiUrl = "https://api.github.com/repos/$repoPath/contents/$RemoteToolsFolder"
    $headers = @{ 'User-Agent' = 'PowerShell Toolkit' }

    try {
        $items = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Warning "Unable to download tools from GitHub: $($_.Exception.Message)"
        return Get-ChildItem -Path $toolDirectory -Filter '*.ps1' | Sort-Object Name
    }

    $downloadCount = 0
    $filesToDownload = $items | Where-Object { $_.type -eq 'file' -and $_.name -like '*.ps1' }
    $totalFiles = $filesToDownload.Count

    foreach ($item in $filesToDownload) {
        $downloadCount++
        $localPath = Join-Path $toolDirectory $item.name
        if (-not (Test-Path $localPath) -or (Get-Item $localPath).Length -ne $item.size) {
            Write-Host "Downloading $($item.name) from GitHub ($downloadCount of $totalFiles)..." -ForegroundColor Cyan
            Download-FileWithProgress -Uri $item.download_url -Destination $localPath -Activity "Downloading tools from GitHub ($downloadCount of $totalFiles)"
        } else {
            Write-Host "Tool already exists, skipping: $($item.name)" -ForegroundColor DarkGray
        }
    }

    return Get-ChildItem -Path $toolDirectory -Filter '*.ps1' | Sort-Object Name
}

function Initialize-Toolkit {
    $AvailableTools = Get-Tools
    return $AvailableTools
}

function Select-Tool {
    param (
        [array]$AvailableTools
    )

    Write-Host "  _____   _____   _______          _ _    _ _   
 |  __ \ / ____| |__   __|        | | |  (_) |  
 | |__) | (___      | | ___   ___ | | | ___| |_ 
 |  ___/ \___ \     | |/ _ \ / _ \| | |/ / | __|
 | |     ____) |    | | (_) | (_) | |   <| | |_ 
 |_|    |_____/     |_|\___/ \___/|_|_|\_\_|\__|
    "
    Write-Host "Welcome to the PowerShell Toolkit!" -ForegroundColor Cyan
    Write-Host "Please select a tool to run:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $AvailableTools.Count; $i++) {
        $toolNumber = $i + 1
        Write-Host "[$toolNumber]: $($AvailableTools[$i].BaseName)" -ForegroundColor Green
    }
    Write-Host "[0]: Exit" -ForegroundColor Yellow

    Write-Host ""
    $selection = Read-Host "Enter the number of the tool you want to run (0-$($AvailableTools.Count))"

    if ($selection -eq "0") {
        exit
    } elseif ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $AvailableTools.Count) {
        $selectedToolIndex = [int]$selection - 1
        $selectedTool = $AvailableTools[$selectedToolIndex]
        Write-Host "Running: $($selectedTool.BaseName)" -ForegroundColor Yellow
        & $selectedTool.FullName
    } else {
        Write-Host "Invalid selection. Please enter a number between 0 and $($AvailableTools.Count)." -ForegroundColor Red
    }
}

# Main
# Initialize the toolkit and get the list of available tools
$AvailableTools = Initialize-Toolkit

#Prompting user for tool selection
Select-Tool $AvailableTools
