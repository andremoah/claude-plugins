# <unit-id> — <purpose in one line>

Path: `<unit path>` · Files: <n> · Lines: <n> · Spec'd: <date>

## Purpose
What this unit does for the business, two or three sentences. Evidence-based; inferences flagged.

## Entry points
How execution reaches this unit: screens/forms, menu items, scheduled jobs, API routes, event
handlers, called-from other units. Each with `path:line`.

## Inputs and outputs
Tables read / written, files read / written, queues, printers, external calls. One line each,
with the operation (read, insert, update, delete) and `path:line`.

## Rules
Every validation, calculation, branch on data, status transition and hard-coded constant.

- R1. <rule in one sentence> — `path:line`
- R2. …

## State and status transitions
If the unit moves records between states, a small table or mermaid `stateDiagram-v2`, each
transition with a citation.

## Depends on
Other units this one calls or whose data it relies on. `unit-id` — why.

## Suspected dead code
Unreachable branches, commented-out blocks, unused procedures. `path:line` each.

## Open questions
Anything inferred, not read. Each also appended to `spec/open-questions.md` with this unit id.

- Q. <question> — raised by `path:line`
