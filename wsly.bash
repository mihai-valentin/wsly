#!/usr/bin/env bash
# wsly.bash — interactive WSL command handoff.
#
# Bash does not read ~/.bashrc when it is invoked with a script filename, even
# with -i. Source it explicitly so interactive-shell functions are available.

if [ -r "${HOME}/.bashrc" ]; then
    # shellcheck disable=SC1090
    . "${HOME}/.bashrc"
fi

if "$@"; then
    exec "${SHELL:-bash}" -i
else
    exit
fi
