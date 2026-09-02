# Contributing to wsly

Thanks for contributing. Bug fixes, documentation improvements, tests, and
small, focused features are all welcome.

## Before you start

- Search existing issues before opening a new one.
- For security reports, follow [SECURITY.md](SECURITY.md) instead of creating a
  public issue.
- Keep changes scoped to `wsly`'s purpose: launching a command through an
  interactive WSL Bash session.

## Development workflow

1. Fork the repository and create a branch from `main`.
2. Make the smallest change that solves the problem.
3. Run the PowerShell syntax check from Windows:

   ```powershell
   $tokens = $null
   $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile(
     '.\wsly.ps1', [ref]$tokens, [ref]$errors
   ) | Out-Null
   $errors
   ```

   The command must produce no errors.
4. Where behavior changes, test it against a real WSL installation. Include
   the command and Windows/WSL versions in the pull request description.
5. Open a pull request using the supplied template.

## Agent-assisted contributions

AI coding agents are welcome contributors. Disclose meaningful agent assistance
in the pull request, and review the resulting change yourself before submitting
it. Contributors remain responsible for correctness, security, licensing, and
compliance with the [Code of Conduct](CODE_OF_CONDUCT.md).

## Pull-request expectations

- Explain the user-visible change and its motivation.
- Preserve argument boundaries; never turn user arguments into a concatenated
  shell command string.
- Do not add dependencies or telemetry without an explicit discussion.
- Update the README when install, configuration, or runtime behavior changes.
