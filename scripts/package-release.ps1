[CmdletBinding()]
param(
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$usingDefaultOutputDirectory = [string]::IsNullOrWhiteSpace($OutputDirectory)
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()
if ($usingDefaultOutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot 'dist'
}
if ($usingDefaultOutputDirectory -and $OutputDirectory -match '^\\\\wsl(?:\.localhost)?\\') {
    # Windows PowerShell cannot create files through its own WSL UNC provider.
    # Use a native Windows temp directory for local builds launched from a WSL
    # checkout; the created path is printed below for installation testing.
    $OutputDirectory = Join-Path $env:TEMP "wsly-$version-release"
}
if (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path (Get-Location).Path $OutputDirectory
}
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
$innoOutput = Join-Path $env:TEMP ("wsly-inno-output-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $innoStaging | Out-Null
New-Item -ItemType Directory -Path $innoOutput | Out-Null
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
    & $iscc.Path "/DAppVersion=$version" "/DSourceDir=$innoStaging" "/DOutputDir=$innoOutput" (Join-Path $innoStaging 'wsly.iss')
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup build failed with exit code $LASTEXITCODE."
    }
    Copy-Item -LiteralPath (Join-Path $innoOutput "$packageName-setup.exe") -Destination $setup
}
finally {
    Remove-Item -LiteralPath $innoStaging -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $innoOutput -Recurse -Force -ErrorAction SilentlyContinue
}

$setupHash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $setupChecksum -Value "$setupHash  $packageName-setup.exe" -NoNewline

Write-Host "Created $archive, $checksum, $setup, and $setupChecksum"
