# Adapters

An adapter answers two questions for one tracker / forge:

1. `fetch-spec <link>` → title, description, acceptance criteria, comments, assignee.
2. `fetch-references` → resolved tickets with actual effort and linked PRs (for `build-references`).

Planned: `jira`, `github`, `linear`, `azure-devops`, `local-md` (spec from a file, no references).
Prefer the user's existing MCP server where one is configured; fall back to REST with a token from env.
