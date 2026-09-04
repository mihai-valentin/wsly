#!/usr/bin/env bash
# wsly.bash — interactive WSL command handoff.
#
# Bash does not read ~/.bashrc when it is invoked with a script filename, even
# with -i. Source it explicitly so interactive-shell functions are available.

if [ -r "${HOME}/.bashrc" ]; then
    # shellcheck disable=SC1090
    . "${HOME}/.bashrc"
fi

if [ "${1-}" = "--complete" ]; then
    shift

    # Windows PowerShell's native-command marshalling drops an empty final
    # argument. The PowerShell bridge sends this sentinel for the word after
    # `wsly cdp `; restore the empty word before driving Bash completion.
    if [ "$#" -gt 0 ] && [ "${!#}" = '--wsly-completion-empty-argument--' ]; then
        set -- "${@:1:$(($# - 1))}" ''
    fi

    # Populate the variables Bash completion functions receive from readline,
    # then invoke the function registered for the command being completed.
    # This mode is called by the PowerShell argument completer; normal wsly
    # command execution never takes this branch.
    if [ "$#" -eq 0 ]; then
        exit 0
    fi

    COMP_WORDS=("$@")
    COMP_CWORD=$(($# - 1))
    COMP_LINE="${COMP_WORDS[*]}"
    COMP_POINT=${#COMP_LINE}
    COMP_TYPE=9
    COMP_KEY=9
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD - 1]:-}
    COMPREPLY=()

    completion_spec=$(complete -p -- "${COMP_WORDS[0]}" 2>/dev/null || true)
    if [[ ${completion_spec} =~ [[:space:]]-F[[:space:]]+([^[:space:]]+) ]]; then
        completion_function=${BASH_REMATCH[1]}
        if declare -F "${completion_function}" >/dev/null; then
            "${completion_function}"
        fi
    fi

    if ((${#COMPREPLY[@]})); then
        printf '%s\n' "${COMPREPLY[@]}"
    fi
    exit 0
fi

if "$@"; then
    exec "${SHELL:-bash}" -i
else
    exit
fi
