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
function Initialize-Toolkit {
    $AvailableTools = Get-ChildItem -Path ".\tools" -Filter "*.ps1" | Sort-Object Name
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
