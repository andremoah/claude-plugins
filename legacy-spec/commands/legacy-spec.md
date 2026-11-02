---
description: Extract a cited spec from a legacy codebase, one unit at a time, with progress kept on disk
argument-hint: init <source-dir> [--max-lines N] | next [N] | run | data <schema-dump-file> | status | assemble | questions
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

Load the `legacy-spec` skill and follow its procedure for the sub-command given in `$ARGUMENTS`.

Sub-commands:

- `init <source-dir> [--max-lines N]` — inventory the source, propose a unit split, create `spec/` with the skeleton and state files. Ask the user to confirm the split before writing it.
- `next [N]` — spec the next N pending units (default 1). Checkpoint after each unit.
- `run` — loop over all pending units, checkpointing after each. Stop early if context is getting tight and tell the user to run `/legacy-spec run` again in a fresh session.
- `data <schema-dump-file>` — spec the database from a schema dump (DDL, `.sql`, CSV of information_schema, or any text export).
- `status` — print progress (`scripts/status.sh`).
- `assemble` — build `spec/index.md` (tree map), merge the glossary, consolidate `open-questions.md` and `data-model/erd.md` from the unit specs.
- `questions` — list all open questions grouped by unit, for the business/domain owner to answer.

Plugin root: `${CLAUDE_PLUGIN_ROOT}`. Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Working dir: `${CLAUDE_PROJECT_DIR}`.
