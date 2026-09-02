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

printf '%s\n' 'wsly.bash tests passed'
