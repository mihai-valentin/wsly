# wsly-completion.ps1 — PowerShell tab completion bridge for wsly.
#
# This file must be loaded into the caller's PowerShell session (the installer
# adds it to the current user's all-hosts profile). It asks the bundled Bash
# helper to run the completion function configured by ~/.bashrc.

$script:WslyCompletionHelper = Join-Path $PSScriptRoot 'wsly.bash'
$script:WslyLauncher = Join-Path $PSScriptRoot 'wsly.ps1'

# A PowerShell function guarantees that Register-ArgumentCompleter is called
# for `wsly`, instead of relying on host-specific completion behavior for a
# .ps1 discovered through PATH.
if (Test-Path -LiteralPath $script:WslyLauncher -PathType Leaf) {
    . $script:WslyLauncher
    function global:wsly {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromRemainingArguments = $true)]
            [string[]]$Command
        )

        Invoke-Wsly -Command $Command
    }
}

function Get-WslyCompletionLauncher {
    if (-not [string]::IsNullOrWhiteSpace($env:WSLY_WSL_EXE)) {
        if ([System.IO.Path]::IsPathRooted($env:WSLY_WSL_EXE)) {
            if (Test-Path -LiteralPath $env:WSLY_WSL_EXE -PathType Leaf) {
                return (Resolve-Path -LiteralPath $env:WSLY_WSL_EXE).Path
            }
            return $null
        }

        $override = Get-Command -Name $env:WSLY_WSL_EXE -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $override) {
            return $override.Path
        }
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
        $systemLauncher = Join-Path $env:SystemRoot 'System32\wsl.exe'
        if (Test-Path -LiteralPath $systemLauncher -PathType Leaf) {
            return $systemLauncher
        }
    }

    $launcher = Get-Command -Name 'wsl.exe', 'wsl' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $launcher) {
        return $launcher.Path
    }

    return $null
}

function Get-WslyCompletionHelperPath {
    param(
        [Parameter(Mandatory)]
        [string]$LauncherPath
    )

    if (-not (Test-Path -LiteralPath $script:WslyCompletionHelper -PathType Leaf)) {
        return $null
    }

    $uncMatch = [regex]::Match(
        $script:WslyCompletionHelper,
        '^\\\\wsl(?:\.localhost)?\\(?<distro>[^\\]+)\\(?<linuxPath>.+)$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if ($uncMatch.Success) {
        return [pscustomobject]@{
            Distro = $uncMatch.Groups['distro'].Value
            Path = '/' + $uncMatch.Groups['linuxPath'].Value.Replace('\', '/')
        }
    }

    $windowsPath = $script:WslyCompletionHelper.Replace('\', '/')
    $linuxPath = & $LauncherPath '--' 'wslpath' '-u' $windowsPath 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($linuxPath)) {
        return $null
    }

    return [pscustomobject]@{ Distro = $null; Path = $linuxPath.Trim() }
}

function ConvertTo-WslyCompletionText {
    param([Parameter(Mandatory)][string]$Text)

    if ($Text -match '[\s''"`$]') {
        return "'" + $Text.Replace("'", "''") + "'"
    }
    return $Text
}

function Get-WslyCompletionResults {
    param(
        [AllowNull()]
        [string]$WordToComplete,
        [Parameter(Mandatory)]
        $CommandAst
    )

    $launcher = Get-WslyCompletionLauncher
    if ($null -eq $launcher) {
        return
    }

    $helper = Get-WslyCompletionHelperPath -LauncherPath $launcher
    if ($null -eq $helper) {
        return
    }

    $words = @(
        $commandAst.CommandElements |
            Select-Object -Skip 1 |
            ForEach-Object {
                if ($null -ne $_.PSObject.Properties['Value']) { [string]$_.Value } else { $_.Extent.Text }
            }
    )
    # For script commands PowerShell can report the prior argument as
    # $wordToComplete after `wsly cdp <Tab>`. CommandAst excludes trailing
    # whitespace, so use PSReadLine's live buffer when it is available to
    # determine that Bash should complete a new, empty argument after cdp.
    $completingNewArgument = $commandAst.Extent.Text -match '\s$'
    if ($null -ne (Get-Command -Name Get-PSReadLineBufferState -ErrorAction SilentlyContinue)) {
        $readLineState = Get-PSReadLineBufferState
        if ($null -ne $readLineState -and $readLineState.Cursor -gt 0) {
            $beforeCursor = $readLineState.InputBuffer.Substring(0, $readLineState.Cursor)
            $completingNewArgument = $beforeCursor -match '\s$'
        }
    }
    if (-not $completingNewArgument -and $wordToComplete -eq '' -and $words.Count -gt 0) {
        $completingNewArgument = $true
    }
    if ($completingNewArgument) {
        # Windows PowerShell drops empty arguments when it invokes wsl.exe.
        # The Bash helper restores this sentinel to an empty completion word.
        $words += '--wsly-completion-empty-argument--'
        $completionPrefix = ''
    }
    elseif ($words.Count -eq 0 -or $words[$words.Count - 1] -ne $wordToComplete) {
        $words += $wordToComplete
    }
    if ($words.Count -eq 0) {
        return
    }
    if (-not $completingNewArgument) {
        $completionPrefix = $words[$words.Count - 1]
    }

    $arguments = @()
    if ($null -ne $helper.Distro) {
        $arguments += '-d', $helper.Distro
    }
    $arguments += '--', 'bash', '-i', $helper.Path, '--complete'

    & $launcher @arguments @words 2>$null |
        Where-Object { $_ -like "$completionPrefix*" } |
        Sort-Object -Unique |
        ForEach-Object {
            $replacement = ConvertTo-WslyCompletionText -Text $_
            [System.Management.Automation.CompletionResult]::new(
                $replacement, $_, 'ParameterValue', $_
            )
        }
}

# A .ps1 found through PATH can be classified as either an external script or
# a native application, depending on the host and command-discovery settings.
# Register both forms so PowerShell never falls back to file completion merely
# because it classified `wsly` differently.
# PowerShell resolves a launcher found through PATH as `wsly.ps1` in some
# hosts and as the extensionless `wsly` command in others. Register both
# spellings; otherwise PowerShell silently uses its filesystem completer.
Register-ArgumentCompleter -CommandName wsly, 'wsly.ps1' -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-WslyCompletionResults -WordToComplete $wordToComplete -CommandAst $commandAst
}

Register-ArgumentCompleter -Native -CommandName wsly, 'wsly.ps1' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    Get-WslyCompletionResults -WordToComplete $wordToComplete -CommandAst $commandAst
}
