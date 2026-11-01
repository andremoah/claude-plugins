#!/usr/bin/env bash
# SessionStart hook: inject overdue / due-soon EXPIRES markers into Claude's context.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

OUT="$(bash "$HERE/scan.sh" --root "$ROOT" 2>/dev/null)"
# Nothing to say when there are no overdue / due-soon items.
if [ -z "$OUT" ] || printf '%s' "$OUT" | grep -q -E '^code-expiry: (no EXPIRES|0 overdue, 0 due)'; then
  exit 0
fi

esc="$(printf '%s' "$OUT" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')"
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[code-expiry] Temporary code with passed or near deadlines exists in this repo. Mention it to the user once this session; offer /code-expiry:expiry reap for overdue items.\\n%s"}}\n' "$esc"
