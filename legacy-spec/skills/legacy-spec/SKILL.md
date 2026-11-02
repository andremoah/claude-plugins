---
name: legacy-spec
description: Reverse-engineer an undocumented legacy system into a validatable specification. Works unit by unit so large systems fit the context window, writes every finding to disk under spec/ with file:line citations, and resumes from the on-disk state in any session. Use when asked to document, spec, reverse-engineer, or understand a legacy codebase or database before a rewrite, migration or handover.
---

# legacy-spec

Goal: a `spec/` folder a domain expert can validate and a new team can build from. Not a code
summary. Every behavioural claim cites where it came from (`path:line` or `table.column`).
Anything the code does not prove goes to **Open questions**, never to prose as fact.

## Why unit by unit

A legacy system rarely fits in one context window and never fits in one sitting. The plugin
therefore keeps all state on disk and treats each unit as one loop iteration:

```
read state → pick next pending unit → read its files → write modules/<unit>.md
→ append glossary/data/questions → mark done → (repeat or stop)
```

A unit is a directory (or a single oversize file) whose text totals at most `--max-lines`
(default 4000). Stopping after any unit loses nothing. A fresh session picks up from
`spec/_state/progress.tsv`.

## On-disk layout (created by `init`, inside the user's project)

```
spec/
  _state/
    inventory.tsv     path  ext  lines  bytes  mtime  kind       (from inventory.sh)
    progress.tsv      unit  status  files  lines  path  notes    (pending|in-progress|done|skipped)
    plan.md           inputs available, chosen max-lines, user decisions, conventions found
  overview.md         what the system is for, who uses it, how it runs (filled as units reveal it)
  index.md            tree map: every unit → purpose, one line, link   (assemble)
  glossary.md         domain terms found in code: name | meaning | evidence
  open-questions.md   numbered, each tagged with unit and what would answer it
  data-model/
    tables.md         one section per table: columns, keys, who reads/writes it (unit refs)
    erd.md            mermaid erDiagram inferred from FKs, joins and naming
  modules/
    <unit-id>.md      one per unit (template below)
  interfaces/
    <name>.md         anything crossing the boundary: files, screens, jobs, APIs, queues, reports
```

## Procedure: init

1. Ask (or take from `$ARGUMENTS`) the source directory. Ask what else exists, in this order of value:
   a database schema dump, runtime samples (log files, exported reports, screenshots as text),
   and anyone who can answer questions. Record answers in `_state/plan.md`.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/inventory.sh --src <dir> --out spec/_state/inventory.tsv`.
   Summarise: files, lines, extensions, binary and data files that will be listed but not read.
3. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan.sh --inventory spec/_state/inventory.tsv --max-lines <N>`.
   Show the proposed units (id, path, files, lines). Flag `oversize`. Ask the user to confirm,
   merge, split or skip units (generated code, vendored libraries and tests are usual skips).
   Default max-lines 4000. Raise it only if the user wants fewer, larger units.
4. Write `spec/_state/progress.tsv` with the header
   `unit\tstatus\tfiles\tlines\tpath\tnotes` and every confirmed unit as `pending`.
5. Create the skeleton: every file in the layout above, with headings and an empty body.
   `overview.md` gets whatever the user already told you, marked as *stated by user*.
6. Run `grep` hints to seed `interfaces/`: look for screen/form/menu definitions, scheduled jobs,
   SQL strings, file open/read/write, network calls, printing/report calls. Write one line per
   hit group into `_state/plan.md` under **Entry point hints**. Do not spec anything yet.
7. Tell the user how many units are pending and that `/legacy-spec next` or `run` continues.

## Procedure: next / run

For each unit, in order of `progress.tsv`:

1. Set status `in-progress`. Read every text file of the unit (from `inventory.tsv`). For an
   `oversize` unit read in sections of ~1500 lines and keep notes between sections.
2. Write `spec/modules/<unit-id>.md` using `templates/module.md`. Rules:
   - Name things the way the code does, then the business term if one is evident. Add both to
     `glossary.md`.
   - Every rule, validation, calculation, branch that depends on data, status transition, and
     hard-coded constant gets a bullet with a `path:line` citation.
   - For every table, file, queue or external call touched: add or update its row in
     `data-model/tables.md` or `interfaces/<name>.md` with this unit as reader/writer.
   - Dead or unreachable code: list it under **Suspected dead code**, do not spec it as behaviour.
   - Anything inferred rather than read (why a rule exists, what a magic number means, who uses
     a screen) goes to `open-questions.md` with the unit id and the file:line that raised it.
3. Set status `done` with a one-line note (purpose). If the unit turned out to be generated code,
   vendored library or pure test, set `skipped` and say why.
4. After each unit, print one line: `done <unit> (<n> rules, <m> tables, <q> questions). Next: <unit>`.
5. `run`: continue while units are pending. If the context has grown large (you have read more
   than roughly 60k lines of source in this session), stop after the current unit and say so.
   The next session resumes.

## Procedure: data

Input is a schema dump as text (DDL, information_schema export, ORM models, or a stored-procedure
dump). No database connection is used. For each table write a section in `data-model/tables.md`:
columns with type and nullability, primary key, foreign keys (explicit, or inferred from naming
and noted as inferred), indexes, triggers and constraints. Then write `data-model/erd.md` as a
mermaid `erDiagram`. Mark inferred relations with a dashed comment. Stored procedures and triggers
are spec'd like code units: rules with citations into the dump file.

## Procedure: assemble

1. Read every `modules/*.md` title and purpose line; write `index.md` as a tree following the
   source directory structure, one line per unit, with links. Mark `skipped` units as such.
2. Rewrite `overview.md`: purpose, actors, main flows (as a short list that references modules),
   runtime shape (how it starts, what schedules it, what it talks to), from the module specs only.
3. De-duplicate `glossary.md` (same term, merge evidence). Sort.
4. Renumber `open-questions.md`, group by unit, mark any that another unit later answered.
5. Report counts: units, rules cited, tables, interfaces, open questions.

## Rules

- Never state behaviour without a citation. Never paraphrase a rule more loosely than the code.
- Do not modernise, judge or propose a target architecture. That is a separate task.
- Do not read binary or `data` kind files; list them in the module's **Inputs/outputs** as present.
- Keep the user's domain language; do not translate identifiers.
- One unit per iteration, state written before moving on. Never hold more than one unit in flight.
