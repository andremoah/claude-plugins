#!/usr/bin/env bash
# SessionStart: if a spec is in progress in this project, say where it stands.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROG="$ROOT/spec/_state/progress.tsv"; [ -f "$PROG" ] || exit 0
LINE="$(awk -F'\t' 'NR>1{c[$2]++} END{printf "%d done, %d pending, %d in-progress", c["done"], c["pending"], c["in-progress"]}' "$PROG")"
case "$LINE" in "*0 pending, 0 in-progress") exit 0;; esac
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[legacy-spec] A spec is in progress in this project: %s units. Continue with /legacy-spec next, see /legacy-spec status, or finish with /legacy-spec assemble when nothing is pending."}}\n' "$LINE"
