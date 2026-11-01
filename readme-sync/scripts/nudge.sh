#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): if the written file maps to a README section, remind once per section per session.
set -uo pipefail
INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | sed -n -E 's/.*"file_path":"([^"]*)".*/\1/p' | head -1)"
[ -z "$FILE" ] && exit 0
case "$FILE" in *README.md|*/.readme-sync) exit 0;; esac
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -f "$ROOT/README.md" ] || exit 0
REL="${FILE#"$ROOT"/}"
SESSION="$(printf '%s' "$INPUT" | sed -n -E 's/.*"session_id":"([^"]*)".*/\1/p' | head -1)"
STATE="${TMPDIR:-/tmp}/readme-sync-${SESSION:-nosession}"

SECTION=""
while IFS=$'\t' read -r name globs; do
  IFS='|' read -ra pats <<< "$globs"
  for p in "${pats[@]}"; do
    [ -z "$p" ] && continue
    # shellcheck disable=SC2053
    if [[ "$REL" == $p ]]; then SECTION="$name"; break 2; fi
  done
done < <(bash "$(dirname "$0")/stale.sh" --root "$ROOT" --sections 2>/dev/null)
[ -z "$SECTION" ] && exit 0

KEY="$(printf '%s' "$SECTION" | tr -c 'A-Za-z0-9' '_')"
grep -qx "$KEY" "$STATE" 2>/dev/null && exit 0
echo "$KEY" >> "$STATE"

cat <<EOF2
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[readme-sync] ${REL} maps to README section \"${SECTION}\". If this change adds, removes or alters something a reader of that section relies on (an operation, stored data, a dependency, a setting), update that section in the same change: what and why, not how. Skip if the behaviour is unchanged. Run /readme-sync check to see every section this change touches."}}
EOF2
