#!/usr/bin/env bash
# Report which coding agent wrote the committed, non-blank lines of code.
#
# Usage: scripts/attribution.sh [revision]   (default: HEAD)
#
# Each line is credited, through git blame, to the commit that last changed
# it. That commit's Co-Authored-By trailer names the agent. Commits without
# an agent trailer authored before attribution started were all written by
# Codex; later ones are reported as unattributed.

set -euo pipefail

revision=${1:-HEAD}
attribution_start=2026-10-29
code_pattern='\.(ps1|bash|sh|cmd|iss)$|^\.github/workflows/.*\.yml$'

commit_agent() {
    local sha=$1 trailers author_date
    trailers=$(git log -1 --format='%(trailers:key=Co-Authored-By,valueonly)' "${sha}")
    if grep -qi 'claude' <<< "${trailers}" && grep -qi 'codex' <<< "${trailers}"; then
        printf '%s\n' 'Codex + Claude Code'
    elif grep -qi 'claude' <<< "${trailers}"; then
        printf '%s\n' 'Claude Code'
    elif grep -qi 'codex' <<< "${trailers}"; then
        printf '%s\n' 'Codex'
    else
        author_date=$(git log -1 --format='%ad' --date=short "${sha}")
        if [[ "${author_date}" < "${attribution_start}" ]]; then
            printf '%s\n' 'Codex'
        else
            printf '%s\n' 'Unattributed'
        fi
    fi
}

# One "<sha> <non-blank lines>" row per commit that still owns code lines.
line_counts=$(
    git ls-tree -r --name-only "${revision}" | grep -E "${code_pattern}" |
        while IFS= read -r path; do
            git blame --line-porcelain "${revision}" -- "${path}"
        done |
        awk '
            length($1) == 40 && $1 ~ /^[0-9a-f]+$/ { sha = $1; next }
            /^\t/ { if (substr($0, 2) ~ /[^ \t\r]/) count[sha]++ }
            END { for (sha in count) print sha, count[sha] }
        '
)

while read -r sha lines; do
    [[ -n "${sha}" ]] || continue
    printf '%s\t%s\n' "$(commit_agent "${sha}")" "${lines}"
done <<< "${line_counts}" |
    awk -F '\t' '
        { lines[$1] += $2 }
        END { for (agent in lines) print lines[agent] "\t" agent }
    ' |
    sort -t "$(printf '\t')" -k1,1nr -k2,2 |
    awk -F '\t' '
        { lines[++n] = $1; agents[n] = $2; total += $1 }
        END {
            printf "%-16s %6s %7s\n", "Agent", "Lines", "Share"
            for (i = 1; i <= n; i++) {
                printf "%-16s %6d %6.1f%%\n", agents[i], lines[i], 100 * lines[i] / total
            }
            printf "%-16s %6d\n", "Total", total
        }
    '
