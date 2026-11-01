---
description: List, extend or remove dated temporary code (EXPIRES markers)
argument-hint: "[overdue|all|audit [path] [--all-todos]|reap [file:line]|extend <file:line> <YYYY-MM-DD>]"
allowed-tools: Bash(bash *scan.sh*), Read, Edit, Write, Grep, Agent
---

Run the scanner and act on `$ARGUMENTS`:

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh" --root "${CLAUDE_PROJECT_DIR:-.}" --all
```

- No argument or `overdue` → show overdue and due-soon items as a short table (date, file:line, summary). Nothing else.
- `all` → same table including items dated later.
- `extend <file:line> <date>` → open that line, replace the date in the marker with the new one, keep everything else untouched. Ask for a one-line reason if none given and append it to the comment.
- `reap [file:line]` → spawn the `code-expiry:reaper` agent on the named item, or on every overdue item one at a time when none is named. Show its proposed diff before applying. Never apply without the user's yes.
- `audit [path] [--all-todos]` → onboarding pass over existing undated temporary code. Run:

  ```
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh" --root "${CLAUDE_PROJECT_DIR:-.}" --candidates [--path <path>] [--all-todos]
  ```

  Lines listed in `.code-expiry-ignore` (`file:line`, previously marked permanent) are already excluded by the scanner; say so in one line if that file exists. Then triage, oldest first, in batches of at most 10 so the user is never flooded:
  1. For each candidate show age, file:line, the comment, and 2-3 lines of the guarded code (Read the range; do not dump whole files).
  2. Propose one of: **mark** with a suggested `EXPIRES: <date> <reason/condition>` (base the date on the comment text, age, and any release/sprint/ticket references nearby; say why you chose it), **permanent** (not temporary after all), or **delete now** (clearly dead; hand to reaper).
  3. Ask the user to confirm per item, or accept the batch. The user decides every date. Never write a date the user has not seen.
  4. Apply confirmed markers with Edit on the existing comment line (prepend `EXPIRES: <date> ` to the comment text; keep the comment syntax of the language). Append confirmed **permanent** items as `file:line` to `.code-expiry-ignore` at the repo root (create it with a one-line header comment if missing) so they never resurface.
  5. Finish with a count: marked / ignored / handed to reaper / skipped. Remind that `.code-expiry-ignore` and the edited files should be committed.

  If the candidate list exceeds 50, show the count and the 10 oldest, and suggest narrowing with a `path` argument.

Marker syntax, when the user asks: `// EXPIRES: YYYY-MM-DD <why temporary, what must be true to delete>`.
