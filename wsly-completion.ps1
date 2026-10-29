# wsly-completion.ps1 — PowerShell tab completion bridge for wsly.
#
# This file must be loaded into the caller's PowerShell session (the installer
# adds it to the current user's all-hosts profile). It asks the bundled Bash
# helper to run the completion function configured by ~/.bashrc.

$script:WslyCompletionHelper = Join-Path $PSScriptRoot 'wsly.bash'
$script:WslyLauncher = Join-Path $PSScriptRoot 'wsly.ps1'
if ($null -eq (Get-Variable -Name WslyCompletionResultCache -Scope Script -ErrorAction SilentlyContinue)) {
    $script:WslyCompletionResultCache = @{}
}
if ($null -eq (Get-Variable -Name WslyCompletionWorkers -Scope Script -ErrorAction SilentlyContinue)) {
    $script:WslyCompletionWorkers = @{}
}
$script:WslyCompletionCacheTtl = [TimeSpan]::FromSeconds(10)

# A PowerShell function guarantees that Register-ArgumentCompleter is called
# for `wsly`, instead of relying on host-specific completion behavior for a
# .ps1 discovered through PATH.
if (Test-Path -LiteralPath $script:WslyLauncher -PathType Leaf) {
    . $script:WslyLauncher
    function global:wsly {
        [CmdletBinding()]
        param(
            [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
            [string[]]$Command,

            [string]$Distro,

            [Alias('n')]
            [switch]$NoShell,

            [Alias('Version', 'v')]
            [switch]$ShowVersion,

            [Alias('t')]
            [switch]$Timing,

            [Alias('q')]
            [switch]$Quiet
        )

        Invoke-Wsly -Command $Command -Distro $Distro -NoShell:$NoShell -ShowVersion:$ShowVersion -Timing:$Timing -Quiet:$Quiet
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
        [string]$LauncherPath,

        [string]$Distro
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
        if (-not [string]::IsNullOrWhiteSpace($Distro) -and $Distro -ne $uncMatch.Groups['distro'].Value) {
            return $null
        }
        return [pscustomobject]@{
            Distro = $uncMatch.Groups['distro'].Value
            Path = '/' + $uncMatch.Groups['linuxPath'].Value.Replace('\', '/')
        }
    }

    try {
        return Resolve-WslyBashHelper -LauncherPath $LauncherPath -Distro $Distro
    }
    catch {
        return $null
    }
}

function ConvertTo-WslyCompletionText {
    param([Parameter(Mandatory)][string]$Text)

    if ($Text -match '[\s''"`$]') {
        return "'" + $Text.Replace("'", "''") + "'"
    }
    return $Text
}

function ConvertTo-WslyNativeCommandLineArgument {
    param([Parameter(Mandatory)][string]$Text)

    if ($Text -notmatch '[\s"]' -and $Text.Length -gt 0) {
        return $Text
    }

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashCount = 0
    foreach ($character in $Text.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append('\', ($backslashCount * 2) + 1)
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append('\', $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append('\', $backslashCount * 2)
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-WslyCompletionRequest {
    param([Parameter(Mandatory)][string[]]$Words)

    $stream = [System.IO.MemoryStream]::new()
    try {
        foreach ($word in $Words) {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($word)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.WriteByte(0)
        }
        return [System.Convert]::ToBase64String($stream.ToArray())
    }
    finally {
        $stream.Dispose()
    }
}

function Stop-WslyCompletionWorker {
    param([Parameter(Mandatory)][string]$Key)

    $worker = $script:WslyCompletionWorkers[$Key]
    if ($null -eq $worker) {
        return
    }
    try { $worker.Input.Close() } catch { }
    try {
        if (-not $worker.Process.HasExited) {
            $worker.Process.Kill()
        }
    }
    catch { }
    try { $worker.Process.Dispose() } catch { }
    $script:WslyCompletionWorkers.Remove($Key)
}

function Clear-WslyCompletionCache {
    [CmdletBinding()]
    param()

    $script:WslyCompletionResultCache.Clear()
    foreach ($key in @($script:WslyCompletionWorkers.Keys)) {
        Stop-WslyCompletionWorker -Key $key
    }
}

function Initialize-WslyCompletion {
    [CmdletBinding()]
    param(
        [string]$Distro
    )

    $launcher = Get-WslyCompletionLauncher
    if ($null -eq $launcher) {
        throw 'wsly could not find a WSL launcher to initialize completion.'
    }
    $helper = Get-WslyCompletionHelperPath -LauncherPath $launcher -Distro $Distro
    if ($null -eq $helper) {
        throw 'wsly could not resolve its Bash completion helper.'
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $null = Get-WslyCompletionWorker -LauncherPath $launcher -Helper $helper
    $stopwatch.Stop()
    [pscustomobject]@{
        Distro = if ([string]::IsNullOrWhiteSpace($helper.Distro)) { 'default' } else { $helper.Distro }
        ElapsedMilliseconds = [math]::Round($stopwatch.Elapsed.TotalMilliseconds)
    }
}

function Get-WslyCompletionWorker {
    param(
        [Parameter(Mandatory)][string]$LauncherPath,
        [Parameter(Mandatory)]$Helper
    )

    $workerKey = '{0}|{1}|{2}' -f $LauncherPath, $Helper.Distro, $Helper.Path
    $existing = $script:WslyCompletionWorkers[$workerKey]
    if ($null -ne $existing -and -not $existing.Process.HasExited) {
        return [pscustomobject]@{ Key = $workerKey; Worker = $existing }
    }
    if ($null -ne $existing) {
        Stop-WslyCompletionWorker -Key $workerKey
    }

    $workerArguments = @()
    if (-not [string]::IsNullOrWhiteSpace($Helper.Distro)) {
        $workerArguments += '-d', $Helper.Distro
    }
    $workerArguments += '--', 'bash', '-i', $Helper.Path, '--complete-server'

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $LauncherPath
    $startInfo.Arguments = (($workerArguments | ForEach-Object { ConvertTo-WslyNativeCommandLineArgument -Text $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'wsly could not start its WSL completion worker.'
    }
    # Drain stderr asynchronously. Interactive Bash can emit job-control
    # warnings when its terminal is redirected by the PowerShell completer.
    $process.BeginErrorReadLine()
    $ready = $false
    while (-not $process.HasExited) {
        $line = $process.StandardOutput.ReadLine()
        if ($null -eq $line) {
            break
        }
        if ($line -eq '__WSLY_COMPLETION_READY__') {
            $ready = $true
            break
        }
    }
    if (-not $ready) {
        try { $process.Dispose() } catch { }
        throw 'wsly completion worker exited before it was ready.'
    }

    $worker = [pscustomobject]@{
        Process = $process
        Input = $process.StandardInput
        Output = $process.StandardOutput
    }
    $script:WslyCompletionWorkers[$workerKey] = $worker
    return [pscustomobject]@{ Key = $workerKey; Worker = $worker }
}

function Invoke-WslyCompletionWorker {
    param(
        [Parameter(Mandatory)][string]$LauncherPath,
        [Parameter(Mandatory)]$Helper,
        [Parameter(Mandatory)][string[]]$Words
    )

    $workerHandle = Get-WslyCompletionWorker -LauncherPath $LauncherPath -Helper $Helper
    try {
        $workerHandle.Worker.Input.WriteLine((ConvertTo-WslyCompletionRequest -Words $Words))
        $candidates = @()
        $readingCandidates = $false
        while ($true) {
            $line = $workerHandle.Worker.Output.ReadLine()
            if ($null -eq $line) {
                throw 'wsly completion worker stopped while handling a request.'
            }
            if ($line -eq '__WSLY_COMPLETION_BEGIN__') {
                $readingCandidates = $true
                continue
            }
            if ($line -eq '__WSLY_COMPLETION_END__') {
                if ($readingCandidates) {
                    return $candidates
                }
                continue
            }
            if ($readingCandidates) {
                $candidates += [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($line))
            }
        }
    }
    catch {
        Stop-WslyCompletionWorker -Key $workerHandle.Key
        throw
    }
}

function Get-WslyCompletionResults {
    param(
        [AllowNull()]
        [string]$WordToComplete,
        [Parameter(Mandatory)]
        $CommandAst,
        [string]$Distro
    )

    $launcher = Get-WslyCompletionLauncher
    if ($null -eq $launcher) {
        return
    }

    $helper = Get-WslyCompletionHelperPath -LauncherPath $launcher -Distro $Distro
    if ($null -eq $helper) {
        return
    }

    $rawWords = @(
        $commandAst.CommandElements |
            Select-Object -Skip 1 |
            ForEach-Object {
                if ($null -ne $_.PSObject.Properties['Value']) { [string]$_.Value } else { $_.Extent.Text }
            }
    )
    $words = @()
    $readingLauncherOptions = $true
    $skipNextWord = $false
    foreach ($word in $rawWords) {
        if ($skipNextWord) {
            $skipNextWord = $false
            continue
        }
        if ($readingLauncherOptions -and $word -in '-n', '-NoShell', '-v', '-Version', '--version', '-t', '-Timing', '-q', '-Quiet') {
            continue
        }
        if ($readingLauncherOptions -and $word -in '-Distro', '-d') {
            $skipNextWord = $true
            continue
        }
        $readingLauncherOptions = $false
        $words += $word
    }
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
    if (-not [string]::IsNullOrWhiteSpace($helper.Distro)) {
        $arguments += '-d', $helper.Distro
    }
    $arguments += '--', 'bash', '-i', $helper.Path, '--complete'

    # PowerShell can call an argument completer again for each Tab press. Keep
    # an exact request's candidates briefly, so cycling the same choices does
    # not repeatedly start WSL and interactive Bash. The helper path and distro
    # form part of the key to keep WSL environments isolated.
    $now = [DateTime]::UtcNow
    foreach ($expiredKey in @($script:WslyCompletionResultCache.Keys)) {
        if (($now - $script:WslyCompletionResultCache[$expiredKey].CreatedAt) -ge $script:WslyCompletionCacheTtl) {
            $script:WslyCompletionResultCache.Remove($expiredKey)
        }
    }
    $cacheSeparator = [string][char]0
    $cacheKey = @([string]$helper.Distro, [string]$helper.Path, ($words -join $cacheSeparator)) -join $cacheSeparator
    $cacheEntry = $script:WslyCompletionResultCache[$cacheKey]
    if ($null -ne $cacheEntry -and ($now - $cacheEntry.CreatedAt) -lt $script:WslyCompletionCacheTtl) {
        $candidates = @($cacheEntry.Candidates)
    }
    else {
        try {
            $candidates = @(Invoke-WslyCompletionWorker -LauncherPath $launcher -Helper $helper -Words $words)
        }
        catch {
            # Completion remains available even if a long-lived worker cannot
            # start on an unusual WSL installation.
            $candidates = @(& $launcher @arguments @words 2>$null)
        }
        $script:WslyCompletionResultCache[$cacheKey] = [pscustomobject]@{
            CreatedAt = $now
            Candidates = $candidates
        }
    }

    $candidates |
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

    Get-WslyCompletionResults -WordToComplete $wordToComplete -CommandAst $commandAst -Distro $fakeBoundParameters['Distro']
}

Register-ArgumentCompleter -Native -CommandName wsly, 'wsly.ps1' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    Get-WslyCompletionResults -WordToComplete $wordToComplete -CommandAst $commandAst
}
