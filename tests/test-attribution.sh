#!/usr/bin/env bash
# Contract tests for scripts/attribution.sh.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="${repo_root}/scripts/attribution.sh"
test_root=$(mktemp -d)
trap 'rm -rf "${test_root}"' EXIT

cd "${test_root}"
git init -q -b main
git config user.name 'wsly test'
git config user.email 'wsly-test@example.invalid'

commit() {
    local date=$1 message=$2
    git add -A
    GIT_AUTHOR_DATE="${date}T12:00:00Z" GIT_COMMITTER_DATE="${date}T12:00:00Z" \
        git commit -q -m "${message}"
}

# Untrailed history before attribution started counts as Codex. Blank lines
# and non-code files are ignored.
printf '%s\n' 'one' '' 'two' 'three' > tool.ps1
printf '%s\n' 'prose' > notes.md
commit 2026-09-01 'feat: initial'

printf '%s\n' 'echo codex' > helper.bash
commit 2026-10-29 $'feat: codex helper\n\nCo-Authored-By: Codex <noreply@openai.com>'

printf '%s\n' 'one' '' 'TWO' 'three' 'four' > tool.ps1
commit 2026-10-30 $'fix: claude edit\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'

printf '%s\n' 'echo human' > extra.sh
commit 2026-11-01 'chore: untrailed after attribution started'

actual=$("${script}")
expected=$(printf '%s\n' \
    'Agent             Lines   Share' \
    'Codex                 3   50.0%' \
    'Claude Code           2   33.3%' \
    'Unattributed          1   16.7%' \
    'Total                 6')

if [[ "${actual}" != "${expected}" ]]; then
    printf 'Unexpected attribution report.\n--- expected\n%s\n--- actual\n%s\n' "${expected}" "${actual}" >&2
    exit 1
fi

# Uncommitted edits do not change the report for a committed revision.
printf '%s\n' 'local edit' >> tool.ps1
if [[ "$("${script}" HEAD)" != "${expected}" ]]; then
    printf '%s\n' 'Uncommitted changes leaked into the report.' >&2
    exit 1
fi

printf '%s\n' 'attribution.sh tests passed'
