# claude-plugins

Claude Code plugins by [André Mota](https://github.com/andremoah). Each folder is one plugin; this repository is also the marketplace that installs them.

```
/plugin install <name> --marketplace andremoah/claude-plugins
```

| Plugin | What it does |
|---|---|
| [code-expiry](code-expiry/) | Temporary code with an expiry date. Dates fallbacks, flags and shims when Claude writes them, surfaces them at session start when due, removes them on command. |
| [feature-estimate](feature-estimate/) | Scopes a feature before anyone commits to a date. Guided setup maps your repos and dependencies; each estimate returns an impact map, risk flags, open questions and a size calibrated to your team's history when available. |
| [legacy-spec](legacy-spec/) | Reverse-engineers an undocumented legacy system into a validatable spec. Inventories the source, splits it into units that fit a context window, specs one unit per iteration with file:line citations, keeps progress on disk so any session resumes, then assembles the tree map, data model and open questions. |
| [readme-sync](readme-sync/) | Keeps the functional README true to the code. Maps README sections to the paths that make them true, flags a section as stale when its code changes and it does not, drafts the edit from the diff, fails CI if asked. |
| [tuneup](tuneup/) | Tunes your Claude Code setup for token cost and accuracy from your own usage data. Measures where tokens go in your transcripts, inventories what loads on every request, detects your stack, then recommends community tools and rules with the token effect, accuracy effect and risk of each. Applies on approval, rechecks a week later. |

## Developing locally

```
claude plugin marketplace add /path/to/claude-plugins
claude plugin install code-expiry
```

A plugin installed from a folder marketplace is read from that folder, so edits are picked up with `/reload-plugins`, no reinstall.

## License

MIT
