#!/usr/bin/env bash
# recheck.sh [--state ~/.claude/tuneup] : compare usage since the last scan with the baseline.
set -uo pipefail
STATE="$HOME/.claude/tuneup"; while [ $# -gt 0 ]; do case "$1" in --state) STATE="$2"; shift 2;; *) shift;; esac; done
B="$STATE/baseline.json"; [ -f "$B" ] || { echo "no baseline at $B. Run /tuneup scan first."; exit 2; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SINCE="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['window']['until'])" "$B")"
python3 "$HERE/usage.py" --since "$SINCE" --json "$STATE/after.json" >/dev/null
python3 - "$B" "$STATE/after.json" <<'PY'
import json, sys
b, a = (json.load(open(p)) for p in sys.argv[1:3])
def per(d, k): return (d["tokens"].get(k, 0) / d["sessions"]) if d["sessions"] else 0
rows = [("sessions", b["sessions"], a["sessions"]), ("tokens / session", b["tokens_per_session"], a["tokens_per_session"]),
        ("output tokens / session", per(b, "output_tokens"), per(a, "output_tokens")),
        ("uncached input / session", per(b, "input_tokens"), per(a, "input_tokens")),
        ("cache hit %", b["cache_hit_pct"], a["cache_hit_pct"]), ("compactions", b["compactions"], a["compactions"]),
        ("repeated reads", b["repeated_reads"], a["repeated_reads"]), ("results > 20 KB", b["big_results"], a["big_results"])]
print(f"# Recheck: baseline {b['window']['since'][:10]}→{b['window']['until'][:10]} vs after {a['window']['since'][:10]}→{a['window']['until'][:10]}\n")
print("| metric | baseline | after | change |\n|---|---|---|---|")
for n, x, y in rows:
    ch = f"{(y - x) / x * 100:+.0f}%" if x else "–"
    print(f"| {n} | {x:,.0f} | {y:,.0f} | {ch} |")
print("\n## Tool result KB per session\n\n| tool | baseline | after |\n|---|---|---|")
names = sorted(set(b["tools"]) | set(a["tools"]), key=lambda k: -(b["tools"].get(k, {}).get("bytes", 0)))[:10]
for k in names:
    bb = b["tools"].get(k, {}).get("bytes", 0) / 1024 / max(b["sessions"], 1); aa = a["tools"].get(k, {}).get("bytes", 0) / 1024 / max(a["sessions"], 1)
    print(f"| {k} | {bb:.0f} | {aa:.0f} |")
print("\nFewer sessions in the after window make per-session numbers noisy; wait for a comparable count.")
PY
