# claude-plugins

Claude Code plugins by [André Mota](https://github.com/andremoah). Each folder is one plugin; this repository is also the marketplace that installs them.

```
/plugin install <name> --marketplace andremoah/claude-plugins
```

| Plugin | What it does |
|---|---|
| [code-expiry](code-expiry/) | Temporary code with an expiry date. Dates fallbacks, flags and shims when Claude writes them, surfaces them at session start when due, removes them on command. |
| [feature-estimate](feature-estimate/) | Scopes a feature before anyone commits to a date. Guided setup maps your repos and dependencies; each estimate returns an impact map, risk flags, open questions and a size calibrated to your team's history when available. |

## Developing locally

```
claude plugin marketplace add /path/to/claude-plugins
claude plugin install code-expiry
```

A plugin installed from a folder marketplace is read from that folder, so edits are picked up with `/reload-plugins`, no reinstall.

## License

MIT
