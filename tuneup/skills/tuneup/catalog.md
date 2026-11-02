# Catalog of optimisations

Each entry: **Signal** (fires from usage.py / setup.sh / stack.sh output) · **Tokens** · **Accuracy** ·
**Risk** · **Apply** · **Source**. Effects: ↓ saves, ↑ costs, = neutral. Accuracy here means the
agent's chance of doing the right thing with the context it has.

## T01 · rtk — compress Bash output before it reaches the model
- Signal: `Bash` share of tool-result bytes ≥ 25% or avg ≥ 1 KB over ≥ 200 calls; `rtk` not on PATH.
- Tokens ↓↓ on Bash results (project claims 60–90% on supported commands). Accuracy = for most commands.
- Risk: output of some commands is rewritten; counts and separators can be mangled (a `grep -c` reporting 0, an `echo ====` line "not found"). Keep built-in Read/Grep/Glob for exact text; they bypass the hook.
- Apply: `brew install rtk` (or cargo), `rtk init --global`, confirm the PreToolUse hook in `~/.claude/settings.json`.
- Source: https://github.com/rtk-ai/rtk

## T02 · context-mode — sandbox for large outputs, search instead of paste
- Signal: results > 20 KB ≥ 10 in the window, or `Read` avg ≥ 4 KB, or WebFetch/log/test-output heavy sessions.
- Tokens ↓↓ on large outputs; ↑ small fixed cost per request (hooks + 6 MCP tool schemas).
- Accuracy = to ↑ (derived answers, less noise); ↓ when the agent needs exact bytes to edit (Edit must see the file; the plugin leaves Read for that).
- Risk: more indirection, learning curve; licence is ELv2, check before commercial use.
- Apply: `/plugin marketplace add mksglu/context-mode` then `/plugin install context-mode@context-mode`.
- Source: https://github.com/mksglu/context-mode

## T03 · caveman — terse replies, full technical content
- Signal: output tokens per session high *and* long prose replies; not already using a terse style rule.
- Tokens ↓ on output (project reports 65–75% on prose). ↑ ~1–1.5k input tokens per turn for the skill text, so net savings can be negative on short or already terse workloads.
- Accuracy = for code and commands; ↓ for anything that needs nuance (clarifications, security warnings, irreversible actions). Pair with a rule: write normally for those.
- Apply: `claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman`, or a short CLAUDE.md style rule with the same exceptions and no per-turn skill cost.
- Source: https://github.com/JuliusBrussee/caveman

## T04 · Language server plugins instead of grep for navigation
- Signal: stack.sh finds C#, TypeScript, Python, Go, Rust, Java or Kotlin; `grep` is a top Bash command or `Grep` tool calls are high.
- Tokens ↓ (one definition/references result instead of grep output across files). Accuracy ↑↑ (exact symbols, callers, implementations).
- Risk: server start-up time; large solutions need the right root.
- Apply: `/plugin install csharp-lsp` (or typescript-lsp, pyright-lsp, gopls-lsp, rust-analyzer-lsp, jdtls-lsp, kotlin-lsp) from the official marketplace; add a CLAUDE.md line: "for definitions, references, implementations and callers use LSP before Grep; Grep for text and config".
- Source: official plugin marketplace (`claude-plugins-official`).

## T05 · Token-budget rules in CLAUDE.md
- Signal: repeated Read of the same file in a session ≥ 20; `Read` avg ≥ 3 KB; results > 20 KB present.
- Tokens ↓. Accuracy = to ↑ (less noise in context) with one caveat: "read only what you need" can under-read; keep "read the part you need" not "read less".
- Risk: low. Over-strict rules make the agent ask more.
- Apply: add a block: read line ranges or grep instead of whole files; never re-read a file just edited; one plain shell command per call with absolute paths; for broad or unclear tasks give a short plan before touching files; stop when the task is done, no extra polishing.
- Source: this catalog.

## T06 · Verify on request only (tests, lint, builds, dev servers)
- Signal: `dotnet test`, `npm test`, `pytest`, `npm run build`, `tsc` among frequent Bash commands and the user did not ask for them each time.
- Tokens ↓↓ (test and build output is among the largest results). **Accuracy ↓**: the agent stops self-checking. Suits experienced users who run checks themselves; wrong for hands-off runs.
- Apply: CLAUDE.md rule: "Do not run lint, tests, builds, type checks or dev servers unless asked in that task. When done, say in one line which check you would run and the command."
- Source: this catalog.

## T07 · Permission allowlist from your own history
- Signal: many short Bash calls of the same safe read-only shape (ls, git status, cat, grep, …); few `permissions.allow` rules.
- Tokens = to ↓ (each prompt is a turn); time ↓↓. Accuracy =.
- Risk: allow only read-only shapes; never wildcard write or network commands.
- Apply: the built-in `/fewer-permission-prompts` skill scans transcripts and proposes the allowlist.
- Source: Claude Code built-in skill.

## T08 · Disable idle plugins and MCP servers
- Signal: plugin enabled or MCP server configured, zero calls in the window (compare setup.sh with usage.py's MCP table).
- Tokens ↓ on *every* request (each tool schema is in the system prompt). Accuracy = to ↑ (fewer tools to choose from). Note: deferred-tool loading already shrinks this on recent versions; the saving is smaller than older advice claims.
- Risk: none; re-enable when needed.
- Apply: set the plugin to `false` in `enabledPlugins`, or move the MCP server to the one project that uses it.
- Source: this catalog.

## T09 · Subagents for exploration, main thread for decisions
- Signal: compactions ≥ 1 per 3 sessions; sessions with hundreds of Grep/Read calls; sidechain usage near zero.
- Tokens ↑ overall (the subagent reads the same files) but the main context stays small → fewer compactions and a longer useful session. Accuracy ↑ on the main thread.
- Risk: the hand-off loses detail; mistakes return with the same confidence as findings. Never delegate a single-file edit or an already-known target.
- Apply: CLAUDE.md delegation rules naming when to use Explore/scout-style agents and when never to.
- Source: this catalog.

## T10 · Compaction hygiene
- Signal: compactions high; long sessions.
- Tokens ↓ (less re-reading after a compaction); accuracy ↑ (the summary keeps what matters).
- Apply: `/compact <focus>` before the auto threshold, with what to keep; put durable facts in memory files instead of relying on the summary; tune `autoCompactWindow` if your version exposes it.
- Source: Claude Code docs.

## T11 · Model and effort per task
- Signal: one top model for ~all turns, including trivial ones and subagents.
- Tokens: cost ↓ per token when smaller models take mechanical work; count = . **Accuracy ↓** on hard tasks if the small model gets them. Keep the strong model for decisions, reviews and anything ambiguous.
- Apply: `model` per subagent definition; `/model` or `effortLevel` per session; `/fast` where offered.
- Source: Claude Code docs.

## T12 · Skills over CLAUDE.md for rarely used instructions
- Signal: instruction files > ~250 lines in total, or several `@imports`, or sections that apply to one kind of task only.
- Tokens ↓ on every request (CLAUDE.md is always loaded; a skill loads when triggered). Accuracy ↑ (fewer competing rules).
- Risk: a skill that does not trigger is a rule the agent never sees; write a precise description.
- Apply: move procedure-like sections to `~/.claude/skills/<name>/SKILL.md`; keep CLAUDE.md to standing rules.
- Source: Claude Code docs (progressive disclosure).

## T13 · Cap Bash output without a new tool
- Signal: same as T01, but the user does not want a third-party binary.
- Tokens ↓ on the long tail. Accuracy = when the cap is generous (e.g. 200 lines); ↓ if truncation hides the error at the end.
- Apply: CLAUDE.md rule to pipe long commands through `| tail -n 200` or `| head -c 20000`, or a PreToolUse hook that appends it to known-noisy commands.
- Source: this catalog.

## T14 · Plan mode for broad or unclear tasks
- Signal: sessions with many edits followed by reverts, or long sessions on a vague first prompt.
- Tokens ↓ in total (less rework) though ↑ up-front. Accuracy ↑↑.
- Apply: CLAUDE.md: "for broad or unclear tasks, give a short plan and wait for approval before touching files"; use `/plan` or plan mode.
- Source: Claude Code docs.

## T15 · Protect the prompt cache
- Signal: cache write share high relative to cache read in long sessions; plugins or MCP servers toggled mid-session.
- Tokens ↓ (cache reads cost a fraction of cache writes). Accuracy =.
- Apply: change settings, plugins and MCP servers between sessions, not during; keep hooks' injected context stable in wording; avoid per-turn dynamic banners.
- Source: Anthropic prompt-caching docs.

## T16 · Memory for repeated facts
- Signal: the same explanation or decision re-given across sessions (user reports), or repeated reads of the same docs files.
- Tokens ↓ (one line in memory vs re-deriving). Accuracy ↑ (consistency).
- Apply: use the built-in memory directory; one fact per file; keep the index short.
- Source: Claude Code docs.
