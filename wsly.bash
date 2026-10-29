#!/usr/bin/env bash
# wsly.bash — interactive WSL command handoff.
#
# wsly invokes Bash with -i. Interactive non-login Bash loads ~/.bashrc before
# executing this helper, so functions and completion definitions are available
# without sourcing the file a second time.

wsly_complete() {
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
}

if [ "${1-}" = "--complete" ]; then
    shift
    wsly_complete "$@"
    exit 0
fi

if [ "${1-}" = "--complete-server" ]; then
    # The PowerShell bridge sends one base64-encoded, NUL-delimited argv list
    # per line. A persistent server keeps interactive Bash and ~/.bashrc warm
    # between Tab presses. Candidate lines are base64-encoded to reserve the
    # protocol marker strings for framing.
    printf '%s\n' '__WSLY_COMPLETION_READY__'
    while IFS= read -r wsly_request; do
        wsly_words=()
        while IFS= read -r -d '' wsly_word; do
            wsly_words+=("${wsly_word}")
        done < <(printf '%s' "${wsly_request}" | base64 --decode)

        printf '%s\n' '__WSLY_COMPLETION_BEGIN__'
        while IFS= read -r wsly_candidate; do
            printf '%s\n' "$(printf '%s' "${wsly_candidate}" | base64 --wrap=0)"
        done < <(wsly_complete "${wsly_words[@]}")
        printf '%s\n' '__WSLY_COMPLETION_END__'
    done
    exit 0
fi

hold=0
if [ "${1-}" = "--wsly-hold" ]; then
    hold=1
    shift
fi

if "$@"; then
    if [ "${hold}" -eq 1 ]; then
        exit 0
    fi
    exec "${SHELL:-bash}" -i
else
    exit
fi
