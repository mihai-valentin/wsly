#!/usr/bin/env bash
# Shell-level contract tests for wsly.bash.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
helper="${repo_root}/wsly.bash"
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT

test_home="${test_root}/home"
workspace="${test_root}/workspace"
shell_marker="${test_root}/shell-marker"
fake_shell="${test_root}/fake-shell"
mkdir -p "${test_home}" "${workspace}"

printf '%s\n' \
    'project_jump() {' \
    '    if [[ $# -ne 1 || $1 != "demo" ]]; then' \
    '        return 64' \
    '    fi' \
    '    cd "${WSLY_TEST_WORKSPACE}"' \
    '}' > "${test_home}/.bashrc"

printf '%s\n' \
    '_project_jump_completion() {' \
    '    COMPREPLY=("demo")' \
    '}' \
    'complete -F _project_jump_completion project_jump' \
    '_greedy_jump_completion() {' \
    '    read -r -t 1 _ || true' \
    '    COMPREPLY=("greedy")' \
    '}' \
    'complete -F _greedy_jump_completion greedy_jump' >> "${test_home}/.bashrc"

printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "%s\\n" "$PWD" > "${WSLY_TEST_MARKER}"' \
    'test "$1" = "-i"' > "${fake_shell}"
chmod +x "${fake_shell}"

HOME="${test_home}" \
SHELL="${fake_shell}" \
WSLY_TEST_MARKER="${shell_marker}" \
WSLY_TEST_WORKSPACE="${workspace}" \
bash --noprofile -i "${helper}" project_jump demo

test -f "${shell_marker}"
test "$(<"${shell_marker}")" = "${workspace}"

rm -f "${shell_marker}"
HOME="${test_home}" \
SHELL="${fake_shell}" \
WSLY_TEST_MARKER="${shell_marker}" \
WSLY_TEST_WORKSPACE="${workspace}" \
bash --noprofile -i "${helper}" --wsly-hold project_jump demo
test ! -e "${shell_marker}"

set +e
HOME="${test_home}" \
SHELL="${fake_shell}" \
WSLY_TEST_MARKER="${shell_marker}" \
WSLY_TEST_WORKSPACE="${workspace}" \
bash --noprofile -i "${helper}" project_jump missing
actual_status=$?
set -e

test "${actual_status}" -eq 64
test ! -e "${shell_marker}"

completion_output=$(HOME="${test_home}" bash --noprofile -i "${helper}" --complete project_jump '')
test "${completion_output}" = 'demo'

completion_output=$(HOME="${test_home}" bash --noprofile -i "${helper}" --complete project_jump --wsly-completion-empty-argument--)
test "${completion_output}" = 'demo'

# Server requests are "<id> <base64 NUL-delimited words>". Windows writes
# CRLF line endings. Each reply is one "__WSLY_COMPLETION_RESULT__ <id>
# <base64 newline-delimited candidates>" line.
encode_words() {
    printf '%s\0' "$@" | base64 | tr -d '\n'
}
decode_reply() {
    local expected_id=$1 marker id payload
    read -r -t 10 marker id payload <&"${WSLY_COMPLETION_SERVER[0]}"
    test "${marker}" = '__WSLY_COMPLETION_RESULT__'
    test "${id}" = "${expected_id}"
    printf '%s' "${payload}" | base64 -d
}

coproc WSLY_COMPLETION_SERVER {
    HOME="${test_home}" bash --noprofile -i "${helper}" --complete-server
}
read -r -t 10 server_ready <&"${WSLY_COMPLETION_SERVER[0]}"
test "${server_ready}" = '__WSLY_COMPLETION_READY__'

# A completion function that reads stdin must not consume later requests.
printf '%s %s\r\n' 1 "$(encode_words greedy_jump '')" >&"${WSLY_COMPLETION_SERVER[1]}"
printf '%s %s\r\n' 2 "$(encode_words project_jump '')" >&"${WSLY_COMPLETION_SERVER[1]}"
test "$(decode_reply 1)" = 'greedy'
test "$(decode_reply 2)" = 'demo'

# An empty candidate list still produces a reply.
printf '%s %s\r\n' 3 "$(encode_words no_completion_defined '')" >&"${WSLY_COMPLETION_SERVER[1]}"
test -z "$(decode_reply 3)"

kill "${WSLY_COMPLETION_SERVER_PID}" 2>/dev/null || true
wait "${WSLY_COMPLETION_SERVER_PID}" 2>/dev/null || true

printf '%s\n' 'wsly.bash tests passed'
