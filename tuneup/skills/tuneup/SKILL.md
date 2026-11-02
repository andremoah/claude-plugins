---
name: tuneup
description: Tune a Claude Code setup for token cost and accuracy. Measures real usage from local transcripts (tokens, cache hit, what each tool brings back into context, repeated reads, compactions), inventories settings, hooks, plugins, MCP servers and CLAUDE.md, detects the tech stack, then recommends community tools and rules with the token effect, the accuracy effect and the risk stated for each. Use when asked to reduce Claude Code cost, cut token usage, speed up sessions, improve accuracy, review or optimise a Claude Code setup, or decide which plugins and hooks to use.
---

# tuneup

Principle: **measure, then recommend, then re-measure.** Never recommend from folklore. Every
recommendation in the report points at a number from this user's own transcripts or setup, and
states what it does to tokens *and* to accuracy. Some optimisations trade one for the other; say so.

State lives in `~/.claude/tuneup/` (user-level, never in a repo): `baseline.json`, `after.json`,
`report-<date>.md`, `applied.log`.

## Procedure: scan

1. **Measure.** `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/usage.py --days N --json ~/.claude/tuneup/baseline.json`
   (default 14 days; add `--project DIR` to limit to one project). Keep the markdown it prints.
2. **Inventory.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh --project DIR`.
3. **Stack.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack.sh DIR [DIR...]` on the project and, if the
   user names them, the sibling repos they work in.
4. **Read the catalog** (`catalog.md`). For each entry, evaluate its **Signal** against the numbers
   from steps 1–3. Keep the entries whose signal fires. Drop entries already in place (tool on PATH,
   plugin enabled, rule present in CLAUDE.md).
5. **Rank** by estimated token impact × confidence, then split into three groups:
   - **Do**: saves tokens, accuracy neutral or better, low risk.
   - **Consider**: saves tokens but costs some accuracy, or costs tokens but buys accuracy. State the
     trade and who it suits.
   - **Skip for you**: popular advice whose signal does not fire here. Name it so the user stops
     wondering about it.
6. **Write the report** to `~/.claude/tuneup/report-<date>.md`:
   - Baseline table (from step 1) and the three or four numbers that matter most, in one sentence each.
   - Setup summary: what loads every request (plugins, MCP servers, hooks, instruction files) with sizes.
   - Recommendations, each: `id` · title · **Evidence** (the number) · **Tokens** · **Accuracy** ·
     **Risk** · **Apply** (exact command or edit) · **Source** (URL from the catalog).
   - "Recheck in a week: `/tuneup recheck`".
7. Print the three Do items and the path of the report. Nothing is changed by `scan`.

## Procedure: apply <id>

1. Find the entry in the last report. Show the exact change: the settings.json diff, the CLAUDE.md
   block, the install command. Explain in one line what it does to tokens and accuracy.
2. Only after a yes: make the change. settings.json edits go through Edit on the file, never a rewrite.
   CLAUDE.md additions go in a clearly delimited block (`<!-- tuneup: <id> -->`). Plugin installs
   run the `claude plugin ...` command and show its output.
3. Append `date · id · what` to `~/.claude/tuneup/applied.log`.
4. Remind: a settings or plugin change alters the system prompt → the prompt cache is rebuilt once.

## Procedure: recheck

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/recheck.sh`. Report the table. Read `applied.log` and attribute
changes to what was applied, with care: fewer sessions, a different kind of work, or a model change also
move the numbers. If the after window has fewer than ~10 sessions, say the comparison is early.

## Procedure: catalog

Print `catalog.md` as a table: id · what · tokens · accuracy · signal.

## Rules

- Numbers come from the scripts, never estimated by hand. If a script fails, say so and continue with
  what is available.
- Do not install, edit or delete anything during `scan`.
- Transcripts stay local. Never quote prompt or code content from them in the report; only counts and sizes.
- Third-party tools are recommended with their own repo URL and their own stated caveats. Savings
  claims from their READMEs are reported as theirs, not verified.
- When the user's own CLAUDE.md already contradicts a recommendation, surface the conflict instead of
  adding a second rule.
