# Windows contract tests using a mock WSL launcher; no WSL installation needed.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# cmd.exe cannot use a WSL UNC path as its working directory.
Set-Location -LiteralPath $env:TEMP

$repoRoot = Split-Path -Parent $PSScriptRoot
$argumentLog = Join-Path $env:TEMP 'wsly-mock-arguments.txt'
$testInstall = Join-Path $env:TEMP ("wsly-tests-" + [guid]::NewGuid())
Remove-Item -LiteralPath $argumentLog -Force -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Path $testInstall
foreach ($file in 'wsly.ps1', 'wsly.bash', 'wsly-completion.ps1', 'VERSION') {
    Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination (Join-Path $testInstall $file)
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'mock-wsl.cmd') -Destination (Join-Path $testInstall 'mock-wsl.cmd')
$env:WSLY_WSL_EXE = Join-Path $testInstall 'mock-wsl.cmd'
$env:WSLY_MOCK_ARGS = $argumentLog

. (Join-Path $testInstall 'wsly.ps1')

$expectedVersion = (Get-Content -LiteralPath (Join-Path $testInstall 'VERSION') -Raw).Trim()
$reportedVersion = Invoke-Wsly -ShowVersion:$true
if ($reportedVersion -ne "wsly $expectedVersion") {
    throw "Unexpected version output: $reportedVersion"
}

Invoke-Wsly -Distro TestDistro -NoShell -Command 'echo', 'hello'
$arguments = Get-Content -LiteralPath $argumentLog -Raw
if ($arguments -notmatch '-d TestDistro' -or $arguments -notmatch '--wsly-hold') {
    throw "NoShell or distro arguments were not forwarded: $arguments"
}

$statusMessages = @()
Invoke-Wsly -Distro TestDistro -Command 'echo', 'hello' -InformationVariable +statusMessages | Out-Null
if ((@($statusMessages | ForEach-Object MessageData) -join "`n") -notmatch 'wsly: starting WSL and loading Bash') {
    throw 'Interactive wsly calls did not report their startup status.'
}

$quietMessages = @()
Invoke-Wsly -Distro TestDistro -Quiet -Command 'echo', 'hello' -InformationVariable +quietMessages | Out-Null
if ((@($quietMessages | ForEach-Object MessageData) -join "`n") -match 'wsly: starting') {
    throw 'Quiet interactive wsly calls still reported startup status.'
}

. (Join-Path $testInstall 'wsly-completion.ps1')
wsly -n printf 'hello' | Out-Null
$arguments = Get-Content -LiteralPath $argumentLog -Raw
if ($arguments -match '(^|\s)-d\s+--') {
    throw "The PowerShell proxy forwarded an empty distro name: $arguments"
}

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput('wsly cdp nex', [ref]$tokens, [ref]$errors)
$commandAst = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)[0]
$completionTexts = @(Get-WslyCompletionResults -WordToComplete 'nex' -CommandAst $commandAst | ForEach-Object { $_.CompletionText })
if ($completionTexts -notcontains 'nexus') {
    throw 'PowerShell completion did not return mock WSL candidates.'
}

$cachedCompletionTexts = @(Get-WslyCompletionResults -WordToComplete 'nex' -CommandAst $commandAst | ForEach-Object { $_.CompletionText })
if ($cachedCompletionTexts -notcontains 'nexus') {
    throw 'Cached PowerShell completion did not return mock WSL candidates.'
}
$completionLaunches = @(
    Get-Content -LiteralPath $argumentLog |
        Where-Object { $_ -match '--complete' }
)
if ($completionLaunches.Count -ne 1) {
    throw "Expected repeated completion to use the result cache; got $($completionLaunches.Count) WSL completion launches."
}

$pathTranslations = @(
    Get-Content -LiteralPath $argumentLog |
        Where-Object { $_ -match 'wslpath' }
)
if ($pathTranslations.Count -ne 2) {
    throw "Expected cached completion to avoid another wslpath launch; got $($pathTranslations.Count) translations."
}

Remove-Item -LiteralPath $argumentLog -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $testInstall -Recurse -Force
Write-Host 'wsly.ps1 tests passed'
