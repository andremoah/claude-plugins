#!/usr/bin/env bash
# readme-sync core. Compares code changes with README changes, per section.
#
#   stale.sh --root DIR [--base REF] [--head REF|--worktree] [--readme FILE] [--ci] [--sections]
#
# Config: <root>/.readme-sync  (INI-like; see examples/.readme-sync). Without it, built-in
# conventions map common path names to four sections.
# Exit 0 = nothing stale. Exit 1 (only with --ci) = a mapped section is stale.
set -uo pipefail

ROOT="."; BASE=""; HEAD=""; WORKTREE=0; README="README.md"; CI=0; SECTIONS_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2;;
    --base) BASE="$2"; shift 2;;
    --head) HEAD="$2"; shift 2;;
    --worktree) WORKTREE=1; shift;;
    --readme) README="$2"; shift 2;;
    --ci) CI=1; shift;;
    --sections) SECTIONS_ONLY=1; shift;;
    *) echo "unknown arg $1" >&2; exit 2;;
  esac
done
cd "$ROOT" || exit 2
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo: $ROOT" >&2; exit 2; }
[ -f "$README" ] || { echo "no $README in $ROOT" >&2; exit 2; }

# ---- config -------------------------------------------------------------
declare -a SEC_NAMES=() SEC_GLOBS=()
load_config() {
  local cur="" line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"; line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue
    if [[ "$line" == \[*\] ]]; then
      cur="${line#\[}"; cur="${cur%\]}"; SEC_NAMES+=("$cur"); SEC_GLOBS+=("")
    elif [ -n "$cur" ]; then
      local i=$((${#SEC_NAMES[@]}-1)); SEC_GLOBS[$i]="${SEC_GLOBS[$i]}|$line"
    fi
  done < "$1"
}
if [ -f .readme-sync ]; then
  load_config .readme-sync
else
  SEC_NAMES=("Main operations" "Data" "Depends on" "Settings")
  SEC_GLOBS=(
    "|*[Cc]ontroller*|*[Rr]oute*|*[Rr]esolver*|*/Queries/*|*/Mutations/*|*/queries/*|*/mutations/*|*[Ee]ndpoint*|*[Hh]andler*|*/api/*|*/graphql/*|*.graphql|*/actions/*"
    "|*[Mm]igration*|*/[Mm]odels/*|*/[Ee]ntities/*|*/[Dd]tos/*|*[Ss]chema*|*/[Rr]epositor*|*/collections/*|*[Ee]vent*|*[Cc]ache*"
    "|*/[Cc]lients/*|*[Cc]lient.cs|*[Cc]lient.ts|*[Cc]lient.js|*[Ii]ntegration*|*[Ee]xternal*|*[Gg]ateway*"
    "|appsettings*.json|*/config/*|*.env.example|manifest*.json|*manifest*.y*ml|*[Ss]ettings*|*[Ff]eature[Ff]lag*|*[Oo]ptions.cs"
  )
fi
if [ "$SECTIONS_ONLY" = 1 ]; then
  for i in "${!SEC_NAMES[@]}"; do printf '%s\t%s\n' "${SEC_NAMES[$i]}" "${SEC_GLOBS[$i]#|}"; done; exit 0
fi

# ---- diff range ---------------------------------------------------------
if [ -z "$BASE" ]; then
  for c in origin/main origin/master main master; do
    git rev-parse -q --verify "$c" >/dev/null 2>&1 && { BASE="$(git merge-base HEAD "$c" 2>/dev/null || true)"; [ -n "$BASE" ] && break; }
  done
  [ -z "$BASE" ] && BASE="HEAD~1"
fi
if [ "$WORKTREE" = 1 ] || [ -z "$HEAD" ]; then
  RANGE_FILES="$(git diff --name-only "$BASE" 2>/dev/null)"           # BASE..worktree (incl. uncommitted)
  README_DIFF="$(git diff -U0 "$BASE" -- "$README" 2>/dev/null)"
  HEAD_LABEL="working tree"
else
  RANGE_FILES="$(git diff --name-only "$BASE" "$HEAD" 2>/dev/null)"
  README_DIFF="$(git diff -U0 "$BASE" "$HEAD" -- "$README" 2>/dev/null)"
  HEAD_LABEL="$HEAD"
fi
[ -z "$RANGE_FILES" ] && { echo "readme-sync: no changes between $BASE and $HEAD_LABEL"; exit 0; }

# ---- which README sections changed? -------------------------------------
# Map heading -> [start,end) line numbers in the HEAD version of the README.
README_AT_HEAD="$( if [ "$HEAD_LABEL" = "working tree" ]; then cat "$README"; else git show "$HEAD:$README"; fi )"
declare -a H_NAMES=() H_START=()
n=0
while IFS= read -r l; do
  n=$((n+1))
  if [[ "$l" =~ ^#{1,6}[[:space:]]+(.*)$ ]]; then H_NAMES+=("${BASH_REMATCH[1]}"); H_START+=("$n"); fi
done <<< "$README_AT_HEAD"
TOTAL=$n
changed_lines="$(printf '%s\n' "$README_DIFF" | sed -n -E 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+)(,([0-9]+))? @@.*/\2 \4/p')"
section_changed() { # $1 = section name (case-insensitive, prefix match on heading)
  local want; want="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  local i s e h
  for i in "${!H_NAMES[@]}"; do
    h="$(printf '%s' "${H_NAMES[$i]}" | tr '[:upper:]' '[:lower:]')"
    [[ "$h" == "$want"* ]] || continue
    s="${H_START[$i]}"; e=$(( i+1 < ${#H_NAMES[@]} ? ${H_START[$((i+1))]} : TOTAL+1 ))
    while read -r ls lc; do
      [ -z "$ls" ] && continue; lc="${lc:-1}"; [ "$lc" = 0 ] && lc=1
      le=$((ls+lc-1))
      if [ "$ls" -lt "$e" ] && [ "$le" -ge "$s" ]; then return 0; fi
    done <<< "$changed_lines"
  done
  return 1
}
heading_exists() {
  local want; want="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; local h
  for h in "${H_NAMES[@]}"; do [[ "$(printf '%s' "$h" | tr '[:upper:]' '[:lower:]')" == "$want"* ]] && return 0; done; return 1
}

# ---- match changed files to sections ------------------------------------
STALE=0
printf 'readme-sync: %s .. %s  (%s)\n\n' "$BASE" "$HEAD_LABEL" "$README"
printf '%-18s %-9s %s\n' "SECTION" "STATUS" "SIGNAL FILES"
for i in "${!SEC_NAMES[@]}"; do
  name="${SEC_NAMES[$i]}"; globs="${SEC_GLOBS[$i]#|}"
  hits=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue; [ "$f" = "$README" ] && continue
    IFS='|' read -ra pats <<< "$globs"
    for p in "${pats[@]}"; do
      [ -z "$p" ] && continue
      # shellcheck disable=SC2053
      if [[ "$f" == $p ]] || [[ "./$f" == $p ]]; then hits="${hits}${f}"$'\n'; break; fi
    done
  done <<< "$RANGE_FILES"
  if [ -z "$hits" ]; then status="ok"; files="-"
  elif ! heading_exists "$name"; then status="NO-HEAD"; files="$(printf '%s' "$hits" | head -3 | paste -sd ',' -)"; STALE=1
  elif section_changed "$name"; then status="updated"; files="$(printf '%s' "$hits" | head -3 | paste -sd ',' -)"
  else status="STALE"; files="$(printf '%s' "$hits" | head -3 | paste -sd ',' -)"; STALE=1
  fi
  cnt="$(printf '%s' "$hits" | grep -c . || true)"; [ "$cnt" -gt 3 ] && files="$files (+$((cnt-3)))"
  printf '%-18s %-9s %s\n' "$name" "$status" "$files"
done
echo
if [ "$STALE" = 1 ]; then
  echo "STALE = code under a mapped path changed, README section did not. NO-HEAD = section missing from README."
  [ "$CI" = 1 ] && exit 1
else
  echo "README sections match the code changes."
fi
exit 0
