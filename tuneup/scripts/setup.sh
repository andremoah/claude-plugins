#!/usr/bin/env bash
# setup.sh [--project DIR] : inventory of the Claude Code setup that costs tokens on every request.
set -uo pipefail
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
while [ $# -gt 0 ]; do case "$1" in --project) PROJECT="$2"; shift 2;; *) shift;; esac; done
CL="$HOME/.claude"
echo "# Setup inventory"; echo
echo "## Tools on PATH"
for t in rtk jq python3 node gh; do if command -v "$t" >/dev/null 2>&1; then echo "- $t: $(command -v "$t")"; else echo "- $t: not found"; fi; done
echo; echo "## Settings ($CL/settings.json)"
python3 - "$CL/settings.json" "$CL/settings.local.json" "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json" <<'PY'
import json, sys, os
for p in sys.argv[1:]:
    if not os.path.exists(p): continue
    try: d = json.load(open(p))
    except Exception as e: print(f"- {p}: unreadable ({e})"); continue
    print(f"- **{p}**")
    for k in ("model", "effortLevel", "autoCompactWindow", "editorMode", "statusLine"):
        if k in d: print(f"  - {k}: {json.dumps(d[k])[:120]}")
    hooks = d.get("hooks", {})
    if hooks:
        for ev, arr in hooks.items():
            for h in arr:
                cmds = [x.get("command", "")[:90] for x in h.get("hooks", [])]
                print(f"  - hook {ev} [{h.get('matcher') or '*'}]: {'; '.join(cmds)}")
    ep = d.get("enabledPlugins", {})
    if ep:
        on = [k for k, v in ep.items() if v]; off = [k for k, v in ep.items() if not v]
        print(f"  - plugins enabled ({len(on)}): {', '.join(on)}")
        if off: print(f"  - plugins disabled ({len(off)}): {', '.join(off)}")
    perm = d.get("permissions", {})
    for k in ("allow", "deny", "ask"):
        if perm.get(k): print(f"  - permissions.{k}: {len(perm[k])} rules")
    if d.get("env"): print(f"  - env: {', '.join(d['env'].keys())}")
PY
echo; echo "## MCP servers"
python3 - "$CL/../.claude.json" "$PROJECT/.mcp.json" <<'PY'
import json, sys, os
for p in sys.argv[1:]:
    p = os.path.normpath(p)
    if not os.path.exists(p): continue
    try: d = json.load(open(p))
    except Exception: continue
    s = d.get("mcpServers", {})
    if s: print(f"- {p}: {', '.join(s.keys())}")
    for proj, pd in (d.get("projects") or {}).items():
        ms = (pd or {}).get("mcpServers") or {}
        if ms: print(f"- {p} [{proj}]: {', '.join(ms.keys())}")
PY
echo; echo "## Instruction files (loaded every session)"
for f in "$CL/CLAUDE.md" "$PROJECT/CLAUDE.md" "$PROJECT/AGENTS.md" "$PROJECT/.claude/CLAUDE.md"; do
  [ -f "$f" ] && printf -- '- %s: %s lines, %s bytes\n' "$f" "$(wc -l <"$f" | tr -d ' ')" "$(wc -c <"$f" | tr -d ' ')"
done
grep -hoE '^@[^ ]+' "$PROJECT/CLAUDE.md" "$CL/CLAUDE.md" 2>/dev/null | sort -u | sed 's/^/- import: /'
echo; echo "## Skills"
[ -d "$CL/skills" ] && ls -1 "$CL/skills" | sed 's/^/- user: /'
[ -d "$PROJECT/.claude/skills" ] && ls -1 "$PROJECT/.claude/skills" | sed 's/^/- project: /'
echo; echo "## Memory"
MEM="$CL/projects"; [ -d "$MEM" ] && printf -- '- transcript dirs: %s · jsonl files: %s · size: %s\n' "$(ls -1 "$MEM" | wc -l | tr -d ' ')" "$(find "$MEM" -name '*.jsonl' | wc -l | tr -d ' ')" "$(du -sh "$MEM" 2>/dev/null | cut -f1)"
