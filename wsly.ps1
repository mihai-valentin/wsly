# wsly.ps1 — run a command through an interactive WSL Bash session.
#
# Interactive-shell functions are not available to `wsl <command>`, because
# WSL runs that command without loading the interactive shell configuration.
# wsly starts interactive Bash, runs the requested command, then keeps that
# shell open on success.

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Command,

    [string]$Distro,

    [Alias('n')]
    [switch]$NoShell,

    [Alias('Version', 'v')]
    [switch]$ShowVersion
)

$versionPath = Join-Path $PSScriptRoot 'VERSION'
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    throw "wsly version file is missing: $versionPath. Reinstall wsly to repair the installation."
}
$script:WslyVersion = (Get-Content -LiteralPath $versionPath -Raw).Trim()

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

function Resolve-WslyBashHelper {
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$LauncherPath,

        [string]$Distro
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
        if (-not [string]::IsNullOrWhiteSpace($Distro) -and $Distro -ne $uncMatch.Groups['distro'].Value) {
            throw "The wsly helper is in WSL distro '$($uncMatch.Groups['distro'].Value)', not requested distro '$Distro'. Install wsly from Windows or omit -Distro."
        }
        return [pscustomobject]@{
            Distro = $uncMatch.Groups['distro'].Value
            Path = '/' + $uncMatch.Groups['linuxPath'].Value.Replace('\', '/')
        }
    }

    # WSL parses backslashes in native-command arguments as escapes. Forward
    # slashes keep a Windows path intact (for example, C:/Users/...); wslpath
    # accepts that spelling and still respects the distro's mount settings.
    $wslCompatibleWindowsPath = $helperPath.Replace('\', '/')
    $pathArguments = @()
    if (-not [string]::IsNullOrWhiteSpace($Distro)) {
        $pathArguments += '-d', $Distro
    }
    $linuxPath = & $LauncherPath @pathArguments '--' 'wslpath' '-u' $wslCompatibleWindowsPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($linuxPath)) {
        throw "wsly could not translate its helper path for WSL: $helperPath"
    }

    return [pscustomobject]@{
        Distro = $Distro
        Path = $linuxPath.Trim()
    }
}

# Kept as a function so the PowerShell profile completion bridge can expose a
# `wsly` function. A function has reliable argument-completer registration;
# invoking the .ps1 file directly continues to work exactly as before.
function Invoke-Wsly {
    [CmdletBinding()]
    param(
        [string[]]$Command,

        [string]$Distro,

        [switch]$NoShell,

        [switch]$ShowVersion
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    if ($null -eq $Command) {
        $commandWords = $null
        $commandWordCount = 0
    } else {
        $commandWords = @($Command)
        $commandWordCount = $commandWords.Count
    }

    if ($ShowVersion -or ($commandWordCount -eq 1 -and $commandWords[0] -in '--version', '-v')) {
        Write-Output "wsly $script:WslyVersion"
        $script:WslyExitCode = 0
        return
    }

    if ($NoShell -and $commandWordCount -eq 0) {
        throw 'wsly -NoShell requires a command.'
    }

    $wslPath = Resolve-WslyWslExecutable

    if ($commandWordCount -eq 0) {
        & $wslPath
        $script:WslyExitCode = $LASTEXITCODE
        return
    }

    $bashHelper = Resolve-WslyBashHelper -LauncherPath $wslPath -Distro $Distro
    $wslArguments = @()
    if ($null -ne $bashHelper.Distro) {
        $wslArguments += '-d', $bashHelper.Distro
    }

    $wslArguments += '--', 'bash', '-i', $bashHelper.Path
    if ($NoShell) {
        $wslArguments += '--wsly-hold'
    }

    & $wslPath @wslArguments @commandWords
    $script:WslyExitCode = $LASTEXITCODE
}

# Dot-sourcing makes Invoke-Wsly available to the profile proxy without
# launching WSL while PowerShell is starting up.
if ($MyInvocation.InvocationName -eq '.') {
    return
}

Invoke-Wsly -Command $Command -Distro $Distro -NoShell:$NoShell -ShowVersion:$ShowVersion
exit $script:WslyExitCode
