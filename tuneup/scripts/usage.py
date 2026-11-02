#!/usr/bin/env python3
"""usage.py — token and tool metrics from local Claude Code transcripts. Standard library only.

  usage.py [--days 14] [--since ISO] [--until ISO] [--project DIR] [--root ~/.claude/projects]
           [--json out.json] [--top 12]

Reads ~/.claude/projects/**/*.jsonl, de-duplicates API usage by message id, attributes tool
result sizes to tool names, and prints a markdown summary. Nothing leaves the machine.
"""
import argparse, collections, datetime as dt, glob, json, os, re, sys

def parse_ts(s):
    try: return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception: return None

def text_len(content):
    if content is None: return 0
    if isinstance(content, str): return len(content)
    if isinstance(content, list):
        return sum(text_len(b.get("text") if isinstance(b, dict) else b) for b in content)
    if isinstance(content, dict): return len(json.dumps(content))
    return len(str(content))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--since"); ap.add_argument("--until")
    ap.add_argument("--project"); ap.add_argument("--root", default=os.path.expanduser("~/.claude/projects"))
    ap.add_argument("--json"); ap.add_argument("--top", type=int, default=12)
    a = ap.parse_args()
    now = dt.datetime.now(dt.timezone.utc)
    since = parse_ts(a.since) if a.since else now - dt.timedelta(days=a.days)
    until = parse_ts(a.until) if a.until else now

    files = glob.glob(os.path.join(a.root, "*", "*.jsonl"))
    if a.project:
        key = "-" + re.sub(r"[^A-Za-z0-9]", "-", os.path.abspath(a.project)).strip("-")
        files = [f for f in files if os.path.basename(os.path.dirname(f)).endswith(key) or key in f]

    tok = collections.Counter(); seen_msg = set()
    per_session = collections.defaultdict(lambda: collections.Counter())
    tool_calls = collections.Counter(); tool_bytes = collections.Counter(); tool_max = collections.Counter()
    tool_of_id = {}; models = collections.Counter(); mcp_servers = collections.Counter()
    reads_per_session = collections.defaultdict(collections.Counter)
    compactions = 0; sidechain_lines = 0; turns = 0; sessions = set(); big_results = []
    bash_cmds = collections.Counter()

    for f in files:
        try: fh = open(f, encoding="utf-8", errors="replace")
        except OSError: continue
        with fh:
            for line in fh:
                try: d = json.loads(line)
                except Exception: continue
                ts = parse_ts(d.get("timestamp", "") or "")
                if ts is None or ts < since or ts > until: continue
                sid = d.get("sessionId") or os.path.basename(f)
                t = d.get("type"); m = d.get("message") if isinstance(d.get("message"), dict) else {}
                if d.get("isSidechain"): sidechain_lines += 1
                if d.get("isCompactSummary"): compactions += 1
                if t == "assistant":
                    sessions.add(sid)
                    u = m.get("usage"); mid = m.get("id") or d.get("requestId") or id(line)
                    if u and mid not in seen_msg:
                        seen_msg.add(mid); turns += 1
                        for k in ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
                            v = u.get(k) or 0; tok[k] += v; per_session[sid][k] += v
                        per_session[sid]["turns"] += 1
                        models[m.get("model") or "?"] += 1
                    for b in m.get("content") or []:
                        if isinstance(b, dict) and b.get("type") == "tool_use":
                            name = b.get("name", "?"); tool_of_id[b.get("id")] = name
                            tool_calls[name] += 1
                            if name.startswith("mcp__"):
                                mcp_servers[name.split("__")[1] if "__" in name else name] += 1
                            inp = b.get("input") or {}
                            if name == "Read" and inp.get("file_path"): reads_per_session[sid][inp["file_path"]] += 1
                            if name == "Bash" and inp.get("command"):
                                first = str(inp["command"]).strip().split()[0:1]
                                bash_cmds[first[0] if first else "?"] += 1
                elif t == "user" and isinstance(m.get("content"), list):
                    for b in m["content"]:
                        if isinstance(b, dict) and b.get("type") == "tool_result":
                            name = tool_of_id.get(b.get("tool_use_id"), "?"); n = text_len(b.get("content"))
                            tool_bytes[name] += n; tool_max[name] = max(tool_max[name], n)
                            if n > 20000: big_results.append((n, name, sid[:8]))

    total_in = tok["input_tokens"] + tok["cache_read_input_tokens"] + tok["cache_creation_input_tokens"]
    cache_hit = (tok["cache_read_input_tokens"] / total_in * 100) if total_in else 0
    repeated = sum(1 for s in reads_per_session.values() for c in s.values() if c > 1)
    total_bytes = sum(tool_bytes.values()) or 1
    out = {
        "window": {"since": since.isoformat(), "until": until.isoformat(), "files": len(files)},
        "sessions": len(sessions), "turns": turns, "tokens": dict(tok), "cache_hit_pct": round(cache_hit, 1),
        "tokens_per_session": round((total_in + tok["output_tokens"]) / len(sessions)) if sessions else 0,
        "compactions": compactions, "sidechain_lines": sidechain_lines, "models": dict(models),
        "tools": {k: {"calls": tool_calls[k], "bytes": tool_bytes[k], "avg": round(tool_bytes[k] / tool_calls[k]) if tool_calls[k] else 0,
                      "max": tool_max[k], "share_pct": round(tool_bytes[k] / total_bytes * 100, 1)} for k in tool_calls},
        "mcp_servers": dict(mcp_servers), "repeated_reads": repeated, "big_results": len(big_results),
        "bash_commands": dict(bash_cmds.most_common(15)),
    }
    if a.json:
        os.makedirs(os.path.dirname(os.path.abspath(a.json)), exist_ok=True)
        with open(a.json, "w") as fh: json.dump(out, fh, indent=1)

    print(f"# Usage {since.date()} → {until.date()}  ({len(files)} transcript files)\n")
    print(f"| metric | value |\n|---|---|")
    print(f"| sessions | {len(sessions)} |\n| API turns | {turns} |")
    print(f"| input tokens (uncached) | {tok['input_tokens']:,} |\n| cache read | {tok['cache_read_input_tokens']:,} |")
    print(f"| cache write | {tok['cache_creation_input_tokens']:,} |\n| output tokens | {tok['output_tokens']:,} |")
    print(f"| cache hit | {cache_hit:.1f}% |\n| tokens per session (all kinds) | {out['tokens_per_session']:,} |")
    print(f"| compactions | {compactions} |\n| subagent (sidechain) lines | {sidechain_lines} |")
    print(f"| repeated Read of same file in a session | {repeated} |\n| tool results > 20 KB | {len(big_results)} |")
    print(f"| models | {', '.join(f'{k} ×{v}' for k, v in models.most_common())} |\n")
    print("## Tool results (what comes back into context)\n")
    print("| tool | calls | total KB | avg KB | max KB | share |\n|---|---|---|---|---|---|")
    for k, _ in sorted(tool_bytes.items(), key=lambda x: -x[1])[: a.top]:
        v = out["tools"][k]
        print(f"| {k} | {v['calls']} | {v['bytes']/1024:.0f} | {v['avg']/1024:.1f} | {v['max']/1024:.0f} | {v['share_pct']}% |")
    if mcp_servers:
        print("\n## MCP servers called\n\n| server | calls |\n|---|---|")
        for k, v in mcp_servers.most_common(): print(f"| {k} | {v} |")
    if bash_cmds:
        print("\n## Bash: first word of command\n\n" + ", ".join(f"{k} ×{v}" for k, v in bash_cmds.most_common(15)))

if __name__ == "__main__": main()
