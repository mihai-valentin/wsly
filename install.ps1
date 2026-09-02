# Installs wsly for the current Windows user.

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'wsly.ps1'
$destinationDirectory = Join-Path $env:LOCALAPPDATA 'wsly\bin'
$destination = Join-Path $destinationDirectory 'wsly.ps1'

if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw "wsly is already installed at $destination. Re-run with -Force to replace it."
}

New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ })
if ($pathEntries -notcontains $destinationDirectory) {
    $newUserPath = @($pathEntries + $destinationDirectory) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
}

if (($env:Path -split ';') -notcontains $destinationDirectory) {
    $env:Path = "$env:Path;$destinationDirectory"
}

Write-Host "Installed wsly to $destination"
Write-Host 'Open a new PowerShell window, then run: wsly <command>'
