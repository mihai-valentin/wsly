# Installs wsly for the current Windows user.

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'wsly.ps1'
$helperSource = Join-Path $PSScriptRoot 'wsly.bash'
$completionSource = Join-Path $PSScriptRoot 'wsly-completion.ps1'
$destinationDirectory = Join-Path $env:LOCALAPPDATA 'wsly\bin'
$destination = Join-Path $destinationDirectory 'wsly.ps1'
$helperDestination = Join-Path $destinationDirectory 'wsly.bash'
$completionDestination = Join-Path $destinationDirectory 'wsly-completion.ps1'

if (-not (Test-Path -LiteralPath $helperSource -PathType Leaf)) {
    throw "wsly helper is missing from this checkout: $helperSource"
}

if (-not (Test-Path -LiteralPath $completionSource -PathType Leaf)) {
    throw "wsly completion bridge is missing from this checkout: $completionSource"
}

if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw "wsly is already installed at $destination. Re-run with -Force to replace it."
}

New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force
Copy-Item -LiteralPath $helperSource -Destination $helperDestination -Force
Copy-Item -LiteralPath $completionSource -Destination $completionDestination -Force

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ })
if ($pathEntries -notcontains $destinationDirectory) {
    $newUserPath = @($pathEntries + $destinationDirectory) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
}

if (($env:Path -split ';') -notcontains $destinationDirectory) {
    $env:Path = "$env:Path;$destinationDirectory"
}

$profileDirectory = Split-Path -Parent $PROFILE.CurrentUserAllHosts
if (-not (Test-Path -LiteralPath $profileDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
    New-Item -ItemType File -Path $PROFILE.CurrentUserAllHosts -Force | Out-Null
}
$completionProfileLine = ". '$($completionDestination.Replace("'", "''"))' # wsly tab completion"
if (-not (Select-String -LiteralPath $PROFILE.CurrentUserAllHosts -SimpleMatch 'wsly tab completion' -Quiet)) {
    Add-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value $completionProfileLine
}

# Make completion available immediately in the PowerShell session that ran the
# installer, as well as in future sessions through the profile entry above.
. $completionDestination

Write-Host "Installed wsly to $destination"
Write-Host 'Tab completion is enabled for new PowerShell windows.'
Write-Host 'Open a new PowerShell window, then run: wsly <command>'
