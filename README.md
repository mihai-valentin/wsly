# wsly

[![100% created with Codex](https://img.shields.io/badge/100%25%20created%20with-Codex-412991)](https://openai.com/codex/)

`wsly` runs a command inside an **interactive** WSL Bash session, then leaves
that session open when the command succeeds.

It exists for commands and shell functions that are configured only by an
interactive Bash startup file. A direct call does not load that configuration,
so this fails when `project-jump` is a shell function:

```powershell
wsl project-jump api
# /bin/bash: line 1: project-jump: command not found
```

After installing `wsly`, this both loads the shell function and leaves you in
the selected project:

```powershell
wsly project-jump api
```

## Prerequisites

- WSL installed and available as `wsl.exe`
- Bash configured for the target distro
- The command or shell function available from interactive Bash. Add its setup
  to `~/.bashrc`.

## Install

From this checkout, in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

The installer copies `wsly.ps1` to `%LOCALAPPDATA%\wsly\bin` and adds that
directory to the current user's `PATH`. Open a new PowerShell window after the
install.

To replace an existing install:

```powershell
.\install.ps1 -Force
```

## WSL launcher discovery

`wsly` chooses the WSL launcher at runtime; it does not embed a machine-specific
path. It uses this order:

1. `WSLY_WSL_EXE`, when you explicitly set it.
2. `%SystemRoot%\System32\wsl.exe`, the native Windows launcher.
3. A discoverable `wsl.exe` or `wsl` application on `PATH`.

That deliberately prefers the native launcher over a WindowsApps execution
alias. For an unusual installation or compatible replacement launcher, set an
override before calling `wsly`:

```powershell
$env:WSLY_WSL_EXE = '<path-to-compatible-wsl-launcher>'
wsly project-jump api
```

The override may also be the name of an application already on `PATH`.

## Usage

```powershell
wsly project-jump api
wsly project-jump api deploy
wsly git status
```

With no arguments, `wsly` behaves like `wsl` and opens your default WSL shell.

Print the installed launcher version with:

```powershell
wsly --version
```

To run a command with your interactive Bash configuration but remain in
PowerShell when it finishes, use `-NoShell` (or its short form, `-n`):

```powershell
wsly -n cdp ls
wsly -NoShell git status
```

This mode streams the command's output and returns its exit code, but does not
open the successful command's follow-on WSL shell.

Arguments are passed as individual command words, rather than assembled into a
shell string. Quote an argument in PowerShell when it contains spaces.

`wsly` does not change PowerShell's working directory. Windows and WSL are
separate processes; instead, it opens a WSL shell whose directory was changed
by the command.

### Tab completion

The installer adds a small `wsly` completion bridge to your PowerShell profile.
It exposes `wsly` as a PowerShell function and, after opening a new PowerShell
window, pressing Tab after `wsly cdp ` asks WSL to run the Bash completion
registered for `cdp`. Its configured choices are then offered by PowerShell.
It works with Bash completion functions defined or loaded by `~/.bashrc`.

Run `install.ps1 -Force` to add completion to an existing installation. By
default, PowerShell cycles candidates when you press Tab. To display its
completion menu instead, add this to your PowerShell profile:

```powershell
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
```

Each Tab press starts WSL to obtain candidates, so it is naturally slower than
completion inside an already-running WSL shell. Completion definitions that
depend on an interactive terminal, terminal UI, or Bash readline internals may
not be portable through the bridge.

## Testing

The repository's CI parses the PowerShell launcher on Windows and runs
shell-level contract tests for the Bash helper on Linux. Run the helper tests
locally with:

```bash
bash tests/test-wsly-bash.sh
```

The final integration check requires a real Windows host with WSL installed:

```powershell
.\install.ps1 -Force
wsly <command>
```

## Design

The launcher is intentionally one file and has no dependencies beyond WSL.
The installed launcher is accompanied by a small Bash helper. `wsly` translates
that helper's path for the active WSL distro, starts interactive Bash with the
helper, and passes your command as individual arguments. The helper explicitly
sources `~/.bashrc`, then runs the command and opens a shell on success.

This avoids passing Bash program text through PowerShell's native-command
argument marshalling. The behavior is equivalent to:

```powershell
<interactive Bash with your ~/.bashrc loaded>
```

If the requested command fails, `wsly` returns that exit code instead of
opening a new shell.

## Contributing

Contributions from humans and coding agents are welcome. Agent-assisted pull
requests are held to the same standard as every other contribution: the person
opening the pull request is responsible for understanding it, testing it, and
responding to review feedback.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, then follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE)
