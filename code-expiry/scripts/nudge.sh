#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit): if freshly written code smells temporary
# and carries no EXPIRES marker, ask Claude to add one.
set -uo pipefail

INPUT="$(cat)"
# Pull the new content without jq: works for Write (content) and Edit (new_string).
NEW="$(printf '%s' "$INPUT" | sed -n -E 's/.*"(content|new_string)":"(.*)".*/\2/p' | head -c 20000)"
[ -z "$NEW" ] && exit 0

# Already dated → fine.
printf '%s' "$NEW" | grep -q -i -E 'EXPIRES[[:space:]]*[:(]|@expires\(|TODO[[:space:]]*\[[0-9]{4}-' && exit 0

SMELL='(TODO|FIXME|HACK)[^\\n]{0,40}(remove|delete|drop|clean ?up|temporary|temp\b|legacy|fallback|shim|workaround|deprecat|migrat|backward[- ]compat|feature[ _-]?flag|kill[ _-]?switch)|\b(legacy|fallback|shim|workaround|polyfill|compat(ibility)?)[A-Za-z]*\b[^\\n]{0,30}(=|\(|:)'
printf '%s' "$NEW" | grep -q -i -E "$SMELL" || exit 0

FILE="$(printf '%s' "$INPUT" | sed -n -E 's/.*"file_path":"([^"]*)".*/\1/p' | head -1)"

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[code-expiry] The code just written to ${FILE:-this file} looks temporary (fallback / shim / flag / 'remove later') but has no deadline. If it is meant to be removed later, add a marker on the comment line, e.g.  // EXPIRES: YYYY-MM-DD <why, and what must be true to delete it>. Pick a realistic date; ask the user if unsure. Skip if the code is permanent."}}
EOF
