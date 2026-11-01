---
description: Check, fix or configure README drift against the code paths each section documents
argument-hint: "[check [--base <ref>]|apply [--base <ref>]|init|ci]"
allowed-tools: Bash(bash *stale.sh*), Bash(git diff*), Bash(git log*), Read, Edit, Write, Grep, Glob
---

Follow the `readme-sync` skill. Act on `$ARGUMENTS` (default `check`):

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/stale.sh" --root "${CLAUDE_PROJECT_DIR:-.}" [--base <ref>]
```

- `check` → run the script, show its table verbatim. For each STALE or NO-HEAD row, read the current section and `git diff <base> -- <signal files>` and say in one line what the section is probably missing. No edits.
- `apply` → `check`, then for each stale section draft the minimal edit (see skill), show it as a diff, apply only after the user says yes. One section at a time.
- `init` → if `.readme-sync` is missing, print the built-in mapping (`--sections`), list this repo's README headings, propose a `.readme-sync` that maps every heading that documents behaviour to the paths found in the repo (use Glob), and write it after confirmation.
- `ci` → print the one-line CI command from the skill for this repo's base branch.
