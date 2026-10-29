# Changelog

## Unreleased

- Keep one interactive WSL Bash completion worker per PowerShell session and
  distro to avoid repeated WSL and Bash startup after the first Tab press.
- Add `Clear-WslyCompletionCache` to clear cached candidates and restart
  completion workers after shell configuration changes.
- Add `Initialize-WslyCompletion` to preheat a completion worker explicitly or
  from a PowerShell profile.
- Time out slow completion requests and worker startup, and fall back to one
  WSL launch per request for the rest of the session when a worker cannot
  start.

## 1.2.0

- Reduce startup latency by loading interactive Bash configuration only once
  per wsly Bash process and caching the helper path for each PowerShell session
  and WSL distro.
- Cache identical Bash completion requests for 10 seconds.
- Add `-Timing` / `-t` timing diagnostics and `-Quiet` / `-q` to suppress
  interactive startup status messages.
- Make local release packaging work when Windows PowerShell is launched from a
  WSL checkout.

## 1.1.2

- Fix automated release packaging of the Inno Setup installer on GitHub Actions.

## 1.1.1

- Add a per-user Inno Setup installer and checksummed setup EXE release asset
  for future Windows Package Manager distribution.

## 1.1.0

- Add PowerShell Tab completion for commands and functions configured by
  interactive Bash.
- Add `wsly --version`, `-n` / `-NoShell`, and `-Distro` options.
- Add optional completion installation, a current-user uninstaller, Windows
  launcher contract tests, and a tag-driven release workflow.

## 1.0.3

- Preserve command failure exit codes and improve bundled helper path handling.
