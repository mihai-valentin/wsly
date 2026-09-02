# wsly.ps1 — run a command through an interactive WSL Bash session.
#
# Interactive-shell functions are not available to `wsl <command>`, because
# WSL runs that command without loading the interactive shell configuration.
# wsly starts interactive Bash, runs the requested command, then keeps that
# shell open on success.

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Command
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-WslyWslExecutable {
    <#
    .SYNOPSIS
    Resolves the WSL launcher without assuming a particular Windows install.

    .DESCRIPTION
    An explicit WSLY_WSL_EXE override wins. Otherwise prefer the system WSL
    launcher over an App Execution Alias, then use commands discoverable on
    PATH. This covers normal installations, redirected Windows directories,
    and users who deliberately install a compatible launcher elsewhere.
    #>
    [OutputType([string])]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:WSLY_WSL_EXE)) {
        if ([System.IO.Path]::IsPathRooted($env:WSLY_WSL_EXE)) {
            if (-not (Test-Path -LiteralPath $env:WSLY_WSL_EXE -PathType Leaf)) {
                throw "WSLY_WSL_EXE does not point to a file: $env:WSLY_WSL_EXE"
            }

            return (Resolve-Path -LiteralPath $env:WSLY_WSL_EXE).Path
        }

        $override = Get-Command -Name $env:WSLY_WSL_EXE -CommandType Application -ErrorAction Stop
        return $override.Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        $systemLauncher = Join-Path $env:SystemRoot 'System32\wsl.exe'
        if (Test-Path -LiteralPath $systemLauncher -PathType Leaf) {
            return $systemLauncher
        }
    }

    $candidates = @(
        Get-Command -Name 'wsl.exe', 'wsl' -All -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandType -eq 'Application' } |
            ForEach-Object { $_.Path } |
            Select-Object -Unique
    )

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }

    throw @"
wsly could not find a WSL launcher. Install WSL, add wsl.exe to PATH, or set
WSLY_WSL_EXE to the full path of a compatible launcher for this session.
"@
}

$wslPath = Resolve-WslyWslExecutable

function Resolve-WslyBashHelper {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$LauncherPath
    )

    $helperPath = Join-Path $PSScriptRoot 'wsly.bash'
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
        throw "wsly helper is missing: $helperPath. Reinstall wsly to repair the installation."
    }

    # A checkout may be invoked through WSL's UNC provider. In that case use
    # its already-native Linux path and explicitly select that same distro.
    $uncMatch = [regex]::Match(
        $helperPath,
        '^\\\\wsl(?:\.localhost)?\\(?<distro>[^\\]+)\\(?<linuxPath>.+)$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if ($uncMatch.Success) {
        return [pscustomobject]@{
            Distro = $uncMatch.Groups['distro'].Value
            Path = '/' + $uncMatch.Groups['linuxPath'].Value.Replace('\', '/')
        }
    }

    $linuxPath = & $LauncherPath '--' 'wslpath' '-u' $helperPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($linuxPath)) {
        throw "wsly could not translate its helper path for WSL: $helperPath"
    }

    return [pscustomobject]@{
        Distro = $null
        Path = $linuxPath.Trim()
    }
}

if ($Command.Count -eq 0) {
    & $wslPath
    exit $LASTEXITCODE
}

$bashHelper = Resolve-WslyBashHelper -LauncherPath $wslPath
$wslArguments = @()
if ($null -ne $bashHelper.Distro) {
    $wslArguments += '-d', $bashHelper.Distro
}

$wslArguments += '--', 'bash', '-i', $bashHelper.Path

& $wslPath @wslArguments @Command
exit $LASTEXITCODE
