#!/usr/bin/env bash
# inventory.sh --src DIR --out spec/_state/inventory.tsv
# One row per text file: path<TAB>ext<TAB>lines<TAB>bytes<TAB>mtime(YYYY-MM-DD)<TAB>kind
# kind: text | data (large text, not scanned line-by-line) | binary (listed, not read)
set -uo pipefail
SRC="."; OUT=""; MAXDATA=$((2*1024*1024))
while [ $# -gt 0 ]; do case "$1" in
  --src) SRC="$2"; shift 2;; --out) OUT="$2"; shift 2;; --max-data-bytes) MAXDATA="$2"; shift 2;; *) echo "unknown $1" >&2; exit 2;; esac; done
[ -d "$SRC" ] || { echo "no such dir: $SRC" >&2; exit 2; }
[ -n "$OUT" ] && { mkdir -p "$(dirname "$OUT")"; exec >"$OUT"; }
BIN_EXT='png|jpg|jpeg|gif|bmp|ico|webp|pdf|zip|gz|tgz|7z|rar|jar|war|dll|exe|so|dylib|bin|class|pyc|o|a|lib|obj|pdb|mdb|accdb|ldb|dbf|fpt|cdx|idx|ttf|otf|woff|woff2|mp3|mp4|avi|mov|doc|xls|ppt|docx|xlsx|pptx'
mtime_of() { if stat -f %Sm -t %Y-%m-%d "$1" >/dev/null 2>&1; then stat -f %Sm -t %Y-%m-%d "$1"; else date -r "$1" +%Y-%m-%d 2>/dev/null || stat -c %y "$1" | cut -c1-10; fi; }
find "$SRC" -type f \
  -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/bin/*' -not -path '*/obj/*' \
  -not -path '*/target/*' -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.svn/*' -not -path '*/spec/_state/*' \
  -print0 | sort -z | while IFS= read -r -d '' f; do
  rel="${f#"$SRC"/}"; ext="${rel##*.}"; [ "$ext" = "$rel" ] && ext=""; extl="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  bytes=$(wc -c <"$f" | tr -d ' '); mt="$(mtime_of "$f")"
  if printf '%s' "$extl" | grep -qxE "$BIN_EXT"; then printf '%s\t%s\t0\t%s\t%s\tbinary\n' "$rel" "$extl" "$bytes" "$mt"; continue; fi
  if ! grep -Iq . "$f" 2>/dev/null; then printf '%s\t%s\t0\t%s\t%s\tbinary\n' "$rel" "$extl" "$bytes" "$mt"; continue; fi
  if [ "$bytes" -gt "$MAXDATA" ]; then printf '%s\t%s\t0\t%s\t%s\tdata\n' "$rel" "$extl" "$bytes" "$mt"; continue; fi
  lines=$(wc -l <"$f" | tr -d ' ')
  printf '%s\t%s\t%s\t%s\t%s\ttext\n' "$rel" "$extl" "$lines" "$bytes" "$mt"
done
