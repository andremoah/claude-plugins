---
name: code-expiry
description: How to date temporary code with EXPIRES markers so it gets removed later. Use when writing or reviewing fallbacks, shims, feature flags, migration bridges, workarounds, legacy compatibility paths, or any code that says "remove later", "temporary", "until X ships", or when the user asks how to mark something as temporary.
---

# Dating temporary code

Temporary code without a deadline becomes permanent. Whenever you write code that exists only until something else happens, put an `EXPIRES` marker on its comment line:

```
// EXPIRES: 2026-09-13 legacy polling fallback; delete once webhook delivery stays at 100% for 30d
```

Rules:

- **Date** is ISO `YYYY-MM-DD`. Pick when the removal should realistically be *possible*, not when you hope to get to it. Typical: next release + buffer, flag rollout + 30 days, migration completion date. If you cannot pick a date, ask the user; do not invent one silently.
- **Reason and condition**, same line: why it is temporary and what must be true to delete it. The reaper agent reads this to decide if removal is safe.
- **One marker per block.** Put it on the line directly above the guarded code (the `if`, the flag check, the shim function), not on the file header.
- **Keep the comment style of the language** (`//`, `#`, `--`, `<!-- -->`). The scanner is language-agnostic.
- Also accepted: `EXPIRES(2026-09-13)`, `@expires(2026-09-13)`, `TODO [2026-09-13]` (eslint-plugin-unicorn style). Prefer `EXPIRES:` in new code.

What counts as temporary: feature flags and kill switches, fallbacks to a legacy path, API version shims, data-migration bridges, polyfills, "backward compatibility" branches, workarounds for a bug in a dependency, hardcoded values awaiting config.

What does not: permanent error handling, business rules, defaults, documented behaviour.

When reviewing a diff that adds such code without a marker, point it out once and propose the marker line. When a marker's date is near or past, mention it and offer `/code-expiry:expiry reap`.
