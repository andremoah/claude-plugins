#!/usr/bin/env bash
# code-expiry scanner: finds EXPIRES markers and reports overdue / due-soon items.
#
# Usage: scan.sh [--root DIR] [--window DAYS] [--json] [--fail-on-overdue] [--all]
#
# Recognised markers (case-insensitive keyword, ISO date):
#   EXPIRES: 2026-09-13            canonical
#   EXPIRES(2026-09-13)
#   @expires(2026-09-13)
#   TODO [2026-09-13]              eslint-plugin-unicorn expiring-todo-comments style
#
# Candidate mode (onboarding / audit):
#   scan.sh --candidates [--path SUBDIR_OR_FILE] [--all-todos] [--json]
#   Lists UNDATED comments that smell temporary (TODO remove / legacy fallback / shim / flag ...)
#   with their age from git blame. Lines listed in .code-expiry-ignore (file:line) are skipped.
#
# Exit codes: 0 ok, 1 overdue found (only with --fail-on-overdue), 2 usage error.

set -euo pipefail

ROOT="${PWD}"
WINDOW=14
JSON=0
FAIL=0
ALL=0
CANDIDATES=0
ALL_TODOS=0
SUBPATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --fail-on-overdue) FAIL=1; shift ;;
    --all) ALL=1; shift ;;
    --candidates) CANDIDATES=1; shift ;;
    --all-todos) ALL_TODOS=1; shift ;;
    --path) SUBPATH="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

TODAY="$(date +%Y-%m-%d)"
DATED='(EXPIRES[[:space:]]*[:(][[:space:]]*|@expires\([[:space:]]*|TODO[[:space:]]*\[)[0-9]{4}-[0-9]{2}-[0-9]{2}'
IS_GIT=0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && IS_GIT=1

# ---------------------------------------------------------------- candidates
if [ $CANDIDATES -eq 1 ]; then
  if [ $ALL_TODOS -eq 1 ]; then
    SMELL='(^|[^A-Za-z])(TODO|FIXME|HACK|XXX)([^A-Za-z]|$)'
  else
    SMELL='((TODO|FIXME|HACK|XXX).{0,60}(remove|delete|drop|clean ?up|temporar|[^a-z]temp[^a-z]|legacy|fallback|shim|workaround|deprecat|migrat|backward[- ]?compat|feature[ _-]?flag|kill[ _-]?switch|rollout|until|once|after)|(//|#|--|/\*|\*).{0,40}[^a-z](legacy|fallback|shim|workaround|polyfill|temporary|backward[- ]?compat|feature[ _-]?flag|kill[ _-]?switch)([^a-z]|$))'
  fi
  TARGET="${SUBPATH:-.}"
  if [ $IS_GIT -eq 1 ]; then
    RAW="$(git -C "$ROOT" grep -n -I -i -E "$SMELL" -- "$TARGET" ':!*.lock' ':!*.min.*' ':!*.md' 2>/dev/null || true)"
  else
    RAW="$(grep -rn -I -i -E "$SMELL" "$ROOT/$TARGET" \
          --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=bin --exclude-dir=obj --exclude-dir=dist --exclude='*.md' \
          2>/dev/null | sed "s#^${ROOT}/##" || true)"
  fi
  # Drop already-dated lines and ignored ones.
  RAW="$(printf '%s\n' "$RAW" | grep -v -i -E "$DATED" || true)"
  IGNORE="$ROOT/.code-expiry-ignore"
  if [ -f "$IGNORE" ]; then
    RAW="$(printf '%s\n' "$RAW" | grep -v -F -f <(grep -v -E '^\s*(#|$)' "$IGNORE" | sed 's/$/:/') || true)"
  fi

  n=0; first=1; TEXT_ROWS=()
  [ $JSON -eq 1 ] && printf '{"today":"%s","candidates":[' "$TODAY"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    file="${line%%:*}"; rest="${line#*:}"; lineno="${rest%%:*}"; text="${rest#*:}"
    summary="$(printf '%s' "$text" | sed -E 's~^[[:space:]]*(//|#|--|/\*|\*|<!--)?[[:space:]]*~~; s~[[:space:]]+$~~')"
    age=""; since=""
    if [ $IS_GIT -eq 1 ]; then
      ts="$(git -C "$ROOT" blame -L "$lineno,$lineno" --porcelain -- "$file" 2>/dev/null | awk '/^author-time /{print $2; exit}')"
      if [ -n "$ts" ]; then
        since="$(date -r "$ts" +%Y-%m-%d 2>/dev/null || date -d "@$ts" +%Y-%m-%d 2>/dev/null || true)"
        age=$(( ( $(date +%s) - ts ) / 86400 ))
      fi
    fi
    n=$((n+1))
    if [ $JSON -eq 1 ]; then
      esc="$(printf '%s' "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      [ $first -eq 0 ] && printf ','
      printf '{"file":"%s","line":%s,"since":"%s","age_days":%s,"text":"%s"}' "$file" "$lineno" "$since" "${age:-null}" "$esc"
      first=0
    else
      TEXT_ROWS+=("$(printf '%6s d  %s:%s  %s' "${age:--}" "$file" "$lineno" "$summary")")
    fi
  done < <(printf '%s\n' "$RAW")
  if [ $JSON -eq 1 ]; then printf '],"count":%s}\n' "$n"
  else
    [ $n -gt 0 ] && printf '%s\n' "${TEXT_ROWS[@]}" | sort -rn
    echo "code-expiry: $n undated candidate(s)$( [ -n "$SUBPATH" ] && printf ' under %s' "$SUBPATH" ), oldest first."
  fi
  exit 0
fi

# ---------------------------------------------------------------- markers
if date -v+1d >/dev/null 2>&1; then
  SOON="$(date -v+"${WINDOW}"d +%Y-%m-%d)"            # BSD / macOS
else
  SOON="$(date -d "+${WINDOW} days" +%Y-%m-%d)"       # GNU
fi

PATTERN="$DATED"

# Prefer git grep (respects .gitignore); fall back to grep -r.
if [ $IS_GIT -eq 1 ]; then
  RAW="$(git -C "$ROOT" grep -n -I -i -E "$PATTERN" -- . ':!*.lock' ':!*.min.*' 2>/dev/null || true)"
else
  RAW="$(grep -rn -I -i -E "$PATTERN" "$ROOT" \
        --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=bin --exclude-dir=obj --exclude-dir=dist \
        2>/dev/null | sed "s#^${ROOT}/##" || true)"
fi

# Don't report ourselves.
RAW="$(printf '%s\n' "$RAW" | grep -v -E '^(scripts/scan\.sh|skills/code-expiry/SKILL\.md|README\.md):' || true)"

overdue=0; soon=0; later=0
rows=()

while IFS= read -r line; do
  [ -z "$line" ] && continue
  file="${line%%:*}"; rest="${line#*:}"
  lineno="${rest%%:*}"; text="${rest#*:}"
  d="$(printf '%s' "$text" | grep -o -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  [ -z "$d" ] && continue
  # Strip leading comment syntax and whitespace for the summary.
  summary="$(printf '%s' "$text" | sed -E 's~^[[:space:]]*(//|#|--|/\*|\*|<!--)?[[:space:]]*~~; s~[[:space:]]+$~~')"
  if [[ "$d" < "$TODAY" ]]; then status=overdue; overdue=$((overdue+1))
  elif [[ "$d" < "$SOON" || "$d" == "$SOON" ]]; then status=soon; soon=$((soon+1))
  else status=later; later=$((later+1)); fi
  rows+=("$status|$d|$file|$lineno|$summary")
done <<< "$RAW"

if [ $JSON -eq 1 ]; then
  printf '{"today":"%s","window_days":%s,"overdue":%s,"due_soon":%s,"later":%s,"items":[' "$TODAY" "$WINDOW" "$overdue" "$soon" "$later"
  first=1
  for r in "${rows[@]+"${rows[@]}"}"; do
    IFS='|' read -r st d f ln s <<< "$r"
    [ $ALL -eq 0 ] && [ "$st" = later ] && continue
    esc="$(printf '%s' "$s" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    [ $first -eq 0 ] && printf ','
    printf '{"status":"%s","date":"%s","file":"%s","line":%s,"text":"%s"}' "$st" "$d" "$f" "$ln" "$esc"
    first=0
  done
  printf ']}\n'
else
  total=$((overdue+soon+later))
  if [ $total -eq 0 ]; then
    echo "code-expiry: no EXPIRES markers found."
  else
    echo "code-expiry: $overdue overdue, $soon due within ${WINDOW}d, $later later (today $TODAY)"
    for r in "${rows[@]+"${rows[@]}"}"; do
      IFS='|' read -r st d f ln s <<< "$r"
      [ $ALL -eq 0 ] && [ "$st" = later ] && continue
      case "$st" in overdue) tag="OVERDUE ";; soon) tag="DUE SOON";; *) tag="later   ";; esac
      printf '  [%s] %s  %s:%s  %s\n' "$tag" "$d" "$f" "$ln" "$s"
    done
  fi
fi

[ $FAIL -eq 1 ] && [ $overdue -gt 0 ] && exit 1
exit 0
