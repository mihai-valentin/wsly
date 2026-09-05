# Changelog

## Unreleased

- Reduce startup latency by loading interactive Bash configuration only once
  per wsly Bash process and caching the helper path for each PowerShell session
  and WSL distro.
- Cache identical Bash completion requests for 10 seconds.
- Add `-Timing` / `-t` timing diagnostics and `-Quiet` / `-q` to suppress
  interactive startup status messages.

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
