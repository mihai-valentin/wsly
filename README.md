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
$env:WSLY_WSL_EXE = 'D:\Tools\wsl.exe'
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

Arguments are passed as individual command words, rather than assembled into a
shell string. Quote an argument in PowerShell when it contains spaces.

`wsly` does not change PowerShell's working directory. Windows and WSL are
separate processes; instead, it opens a WSL shell whose directory was changed
by the command.

## Design

The launcher is intentionally one file and has no dependencies beyond WSL.
Internally it uses the equivalent of:

```powershell
wsl.exe -- bash -ic '<command>; exec bash -i'
```

but safely forwards the original argument vector. Interactive Bash sources
`~/.bashrc`, allowing configured shell functions to be resolved. If the
requested command fails, `wsly` returns its exit code instead of opening a new
shell.

## Contributing

Contributions from humans and coding agents are welcome. Agent-assisted pull
requests are held to the same standard as every other contribution: the person
opening the pull request is responsible for understanding it, testing it, and
responding to review feedback.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, then follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE)
