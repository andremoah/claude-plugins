---
description: Tune your Claude Code setup for token cost and accuracy from your own usage data
argument-hint: [scan [--days N] [--project DIR]] | apply <id> | recheck | catalog
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

Load the `tuneup` skill and follow its procedure for the sub-command in `$ARGUMENTS` (default `scan`).

- `scan [--days N] [--project DIR]` — measure usage from local transcripts, inventory the setup, detect the stack, write `~/.claude/tuneup/report-<date>.md` with ranked recommendations and save `baseline.json`.
- `apply <id>` — apply one recommendation from the last report, after showing the exact change and getting a yes.
- `recheck` — compare usage since the last scan with the baseline, per metric and per tool.
- `catalog` — list every optimisation the plugin knows, with its token and accuracy effect.

Plugin root: `${CLAUDE_PLUGIN_ROOT}`. Scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Catalog at `${CLAUDE_PLUGIN_ROOT}/skills/tuneup/catalog.md`.
