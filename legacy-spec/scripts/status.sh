#!/usr/bin/env bash
# status.sh [--spec spec] : progress table. Exit 0 always.
set -uo pipefail
SPEC="spec"; while [ $# -gt 0 ]; do case "$1" in --spec) SPEC="$2"; shift 2;; *) shift;; esac; done
PROG="$SPEC/_state/progress.tsv"
[ -f "$PROG" ] || { echo "legacy-spec: no $PROG. Run /legacy-spec init <source-dir>."; exit 0; }
awk -F'\t' 'NR>1{c[$2]++; l[$2]+=$4} END{
  printf "legacy-spec: %d done, %d in-progress, %d pending, %d skipped (units)\n", c["done"], c["in-progress"], c["pending"], c["skipped"]
  printf "             %d / %d lines covered\n", l["done"], l["done"]+l["in-progress"]+l["pending"]+l["skipped"] }' "$PROG"
echo
printf '%-28s %-12s %6s %7s  %s\n' UNIT STATUS FILES LINES NOTES
awk -F'\t' 'NR>1{printf "%-28s %-12s %6s %7s  %s\n", substr($1,1,28), $2, $3, $4, $6}' "$PROG"
