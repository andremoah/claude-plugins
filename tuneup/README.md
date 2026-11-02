# tuneup

Tunes your Claude Code setup for token cost and accuracy, from your own usage data.

Most advice about saving tokens is folklore: install this hook, add that rule, disable MCP servers. Some of it is right for you, some of it costs accuracy you did not mean to give up, and none of it comes with a number. tuneup measures first. It reads your local transcripts to see where tokens actually go, inventories what loads on every request, looks at the stack you work in, and only then recommends community tools and rules, each with its token effect, its accuracy effect and its risk stated. It changes nothing until you say yes, and re-measures a week later.

## How it works

![Measure usage from local transcripts, inventory the setup, detect the stack; match the catalog of optimisations against the evidence; write a ranked report with token effect, accuracy effect and risk per item; apply on approval; recheck against the baseline](docs/how-it-works.svg)

1. **Measure.** `scripts/usage.py` parses the JSONL transcripts under `~/.claude/projects` for the last 14 days: sessions, turns, input and output tokens, cache hit rate, compactions, how many bytes each tool brought back into context, repeated reads of the same file, results over 20 KB, which MCP servers were called, which shell commands run most. Numbers only; no prompt or code content leaves the machine or enters the report.
2. **Inventory.** `scripts/setup.sh` lists what is loaded on every request: model and effort, hooks, enabled and disabled plugins, MCP servers, permission rules, instruction files and their sizes, skills, tools on PATH.
3. **Stack.** `scripts/stack.sh` detects the languages and frameworks in your repos and maps them to language-server plugins.
4. **Match.** The catalog (`skills/tuneup/catalog.md`) holds sixteen optimisations, each with the signal that justifies it. Only entries whose signal fires in your data make the report; what is already in place is skipped.
5. **Report.** `~/.claude/tuneup/report-<date>.md`: baseline table, what loads every request, then recommendations in three groups. **Do**: saves tokens, accuracy neutral or better. **Consider**: a trade, stated. **Skip for you**: popular advice your numbers do not support.
6. **Apply and recheck.** `/tuneup apply <id>` shows the exact change and makes it after a yes. `/tuneup recheck` compares usage since the scan with the baseline, metric by metric and tool by tool.

## Example

From a real scan (numbers rounded):

```
Bash results   33% of all bytes brought into context, 1900 calls, grep is the top command
Read results   25%, 67 repeated reads of the same file within a session
Results >20KB  30 in two weeks        Compactions  43 in 71 sessions
```

Report, Do group: language-server plugin for the detected languages instead of grep (tokens ↓, accuracy ↑↑); CLAUDE.md token-budget block, "read the part you need, never re-read a file you just edited" (tokens ↓, accuracy =); rtk already installed, nothing to do. Consider: caveman (output ↓, adds input per turn, loses nuance; pair with exceptions). Skip for you: disabling MCP servers, all configured servers were used in the window.

## Commands

```
/tuneup scan [--days N] [--project DIR]   measure, inventory, detect, report; changes nothing
/tuneup apply <id>                        one recommendation, shown first, applied after a yes
/tuneup recheck                           usage since the scan vs the baseline
/tuneup catalog                           every optimisation the plugin knows
```

## The catalog

rtk · context-mode · caveman · language-server plugins · token-budget rules · verify on request · permission allowlist from history · idle plugins and MCP servers · subagents for exploration · compaction hygiene · model and effort per task · skills over CLAUDE.md · Bash output cap · plan mode · prompt-cache protection · memory for repeated facts.

Each entry states what it does to tokens and to accuracy. Several trade one for the other. "Verify on request" cuts the largest results but stops the agent from self-checking; "caveman" cuts output but adds input on every turn; subagents cost more tokens overall but keep the main context small. The report says which side of each trade your data puts you on.

## Design choices

- **Evidence or nothing.** A recommendation without a number from your transcripts or setup is not made.
- **Accuracy is a first-class column.** Saving tokens by making the agent worse is not a saving.
- **Third-party claims stay third-party.** Savings quoted from a tool's README are reported as the author's, with the link.
- **Local only.** Transcripts are read on your machine. The report holds counts and sizes, never content.
- **Nothing changes during a scan.** Apply is a separate command, per item, after you see the diff.

## Install

```
/plugin install tuneup --marketplace andremoah/claude-plugins
/tuneup scan
```

Requires `python3` for the measurement script; everything else is bash.

## What is inside

- `scripts/usage.py` — transcript measurement, markdown + JSON; `scripts/setup.sh` — setup inventory; `scripts/stack.sh` — stack detection; `scripts/recheck.sh` — before/after comparison
- `commands/tuneup.md` — scan · apply · recheck · catalog
- `skills/tuneup/SKILL.md` — the procedure and rules; `skills/tuneup/catalog.md` — the optimisations
