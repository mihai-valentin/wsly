[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\dist')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$packageName = "wsly-$version"
$packageDirectory = Join-Path $OutputDirectory $packageName
$archive = Join-Path $OutputDirectory "$packageName.zip"
$checksum = "$archive.sha256"
$setup = Join-Path $OutputDirectory "$packageName-setup.exe"
$setupChecksum = "$setup.sha256"

if ([string]::IsNullOrWhiteSpace($version)) {
    throw 'VERSION must not be empty.'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if ((Test-Path -LiteralPath $packageDirectory) -or (Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $checksum) -or (Test-Path -LiteralPath $setup) -or (Test-Path -LiteralPath $setupChecksum)) {
    throw "Release output already exists in $OutputDirectory; choose an empty output directory."
}

New-Item -ItemType Directory -Path $packageDirectory | Out-Null
Copy-Item -LiteralPath @(
    (Join-Path $repoRoot 'CHANGELOG.md'),
    (Join-Path $repoRoot 'LICENSE'),
    (Join-Path $repoRoot 'README.md'),
    (Join-Path $repoRoot 'VERSION'),
    (Join-Path $repoRoot 'install.ps1'),
    (Join-Path $repoRoot 'uninstall.ps1'),
    (Join-Path $repoRoot 'wsly.bash'),
    (Join-Path $repoRoot 'wsly-completion.ps1'),
    (Join-Path $repoRoot 'wsly.ps1')
) -Destination $packageDirectory

Compress-Archive -LiteralPath $packageDirectory -DestinationPath $archive
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksum -Value "$hash  $packageName.zip" -NoNewline

$iscc = Get-Command -Name ISCC.exe -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $iscc) {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $iscc = [pscustomobject]@{ Path = $candidate }
            break
        }
    }
}
if ($null -eq $iscc) {
    throw 'Inno Setup 6 was not found. Install it with: winget install JRSoftware.InnoSetup'
}

$innoStaging = Join-Path $env:TEMP ("wsly-inno-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $innoStaging | Out-Null
try {
    Copy-Item -LiteralPath @(
        (Join-Path $repoRoot 'VERSION'),
        (Join-Path $repoRoot 'wsly.ps1'),
        (Join-Path $repoRoot 'wsly.bash'),
        (Join-Path $repoRoot 'wsly-completion.ps1'),
        (Join-Path $repoRoot 'installer\wsly.iss')
    ) -Destination $innoStaging

    # ISCC does not support a WSL UNC path as its source directory. Staging
    # also makes the local release build work from a WSL checkout.
    & $iscc.Path "/DAppVersion=$version" "/DSourceDir=$innoStaging" "/DOutputDir=$OutputDirectory" (Join-Path $innoStaging 'wsly.iss')
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Remove-Item -LiteralPath $innoStaging -Recurse -Force -ErrorAction SilentlyContinue
}

$setupHash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $setupChecksum -Value "$setupHash  $packageName-setup.exe" -NoNewline

Write-Host "Created $archive, $checksum, $setup, and $setupChecksum"
