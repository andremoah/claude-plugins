---
name: readme-sync
description: Keep a repository's functional README in step with its code. Use when code changes touch operations, stored data, dependencies or settings, when asked whether the README is up to date, when drafting a README section from a diff, or when asked to set up README drift checks or CI for them.
---

# readme-sync

The README is the document support, product, on-call and developer portals read. It states **what** the component does and **why**, per section. Code changes under a section's paths make that section suspect. This skill detects that and drafts the fix; a person approves it.

## Mechanics

`scripts/stale.sh` compares a diff range (default: merge-base with main → working tree) against `.readme-sync` (section → path globs; built-in conventions when absent) and reports per section: `ok`, `updated`, `STALE` (code changed, section not) or `NO-HEAD` (section missing). `--ci` exits 1 on STALE/NO-HEAD.

The PostToolUse hook nudges once per section per session when an edited file maps to a section. It never edits.

## Drafting a section edit (`apply`)

1. Read the whole current section. Keep its heading, its position and its style (tables stay tables, bullets stay bullets).
2. Read the diff of the signal files, not the files. The edit describes what changed for a reader, not the implementation.
3. Write the minimal change: add a row or bullet for something new, change the line for something altered, remove the line for something deleted. Do not rewrite untouched lines.
4. State behaviour and purpose. No class names, method names or file paths unless the section already uses them. No "how".
5. Never invent. If the diff does not show what a reader needs to know (why a setting exists, which system is called), put a `<!-- TODO: confirm … -->` and tell the user.
6. Never include secrets, credentials, internal hostnames or personal data, even if the diff contains them.
7. If the README has a one-line summary (a `>` line under the title) and the change alters the component's purpose, propose a new line of at most 140 characters separately.
8. Show the edit as a diff. Apply only after an explicit yes. One section per approval.

## `init`

Map only headings that document behaviour (operations, data, dependencies, settings, build/run). Skip narrative headings (intro, licence, contributing). Prefer a few broad globs over many narrow ones; a false "STALE" costs a glance, a false "ok" costs a wrong doc.

## CI

```
bash <plugin-root>/scripts/stale.sh --root . --base origin/main --head HEAD --ci
```

Or vendor `scripts/stale.sh` and `.readme-sync` into the repo. Pair with a reviewer rule: a STALE row needs either the README change or a one-line "no reader-visible change" in the PR.
