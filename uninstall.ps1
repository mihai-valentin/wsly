# Uninstalls wsly for the current Windows user.

[CmdletBinding()]
param(
    [switch]$KeepCompletionProfileEntry,
    [switch]$KeepPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$destinationDirectory = Join-Path $env:LOCALAPPDATA 'wsly\bin'
$profileMarker = 'wsly tab completion'

if (-not $KeepCompletionProfileEntry -and (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts -PathType Leaf)) {
    $profileLines = Get-Content -LiteralPath $PROFILE.CurrentUserAllHosts
    $remainingLines = @($profileLines | Where-Object { $_ -notlike "*$profileMarker*" })
    if ($remainingLines.Count -ne $profileLines.Count) {
        Set-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value $remainingLines
        Write-Host "Removed wsly's completion entry from $PROFILE.CurrentUserAllHosts"
    }
}

foreach ($file in 'wsly.ps1', 'wsly.bash', 'wsly-completion.ps1', 'VERSION') {
    $path = Join-Path $destinationDirectory $file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Remove-Item -LiteralPath $path -Force
    }
}

if (Test-Path -LiteralPath $destinationDirectory -PathType Container) {
    $remainingFiles = @(Get-ChildItem -LiteralPath $destinationDirectory -Force)
    if ($remainingFiles.Count -eq 0) {
        Remove-Item -LiteralPath $destinationDirectory -Force
    }
}

if (-not $KeepPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathEntries = @($userPath -split ';' | Where-Object { $_ -and $_ -ne $destinationDirectory })
    [Environment]::SetEnvironmentVariable('Path', ($pathEntries -join ';'), 'User')
    $env:Path = @($env:Path -split ';' | Where-Object { $_ -ne $destinationDirectory }) -join ';'
}

Write-Host 'Uninstalled wsly.'
