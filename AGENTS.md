# Project Memory and Workflow Constraints

This repository's long-term project memory lives in `.project-memory/`. Memory uses an "index + chunked body" layout: each topic's `MEMORY.md` only routes, and fact bodies are read on demand.

## Task Routing

- Every new task first uses `read-index-memory` to read all topic indexes, then reads only the bodies relevant to the task; a task that touches an area designed but not built yet also reads that `Plan/` body.
- Pure consultation, code review, or external research does not enter the modification loop; the memory-reading, documentation-lookup and output constraints still apply.
- Adding, fixing, refactoring, configuration, tests, docs or prompt syncs are "modification tasks" and follow the loop below.

## Modification Task Loop (MUST)

### 1. Before modifying

- Read the project memory bodies relevant to the current task and confirm the project boundary, target, design and effective constraints.
- Identify the modification entry point, callers/callees, the affected data or state flow, and the available verification methods.

### 2. Execution

- Use `update_plan` only when the task really has more than three interdependent steps, multiple independent decisions, or otherwise complex decomposition; update it with actual progress and mark completed steps immediately.
- For external documentation and version-sensitive changes, follow the Documentation Lookup Boundary below.
- Reuse existing implementations and conventions; make the smallest change that works; prefer the standard library or existing dependencies; do not refactor unrelated code, drop requirements, or change behavior that was not asked for.
- Keep going on complex tasks until "implemented, results checked, found problems fixed, verification complete" are all done; do not stop early just because the first version is implemented, unless a safety boundary genuinely needs a user decision.

### 3. Verification

- Every completed modification task (including configuration, templates, docs and prompts) must run the `post-verify` skill.

### 4. Memory consolidation

- Memory consolidation is the last step of a task: once verification passes and before delivery, write the facts this task confirmed. Do not defer it to a later staged sync or commit.
- After verification, invoke `update-memory` only when a current fact is confirmed from code, configuration, diffs, verification or an explicit user statement, a reusable execution lesson is confirmed, or existing memory conflicts with the current implementation. Do not record speculation, transient failures or unimplemented plans; follow the skill for topic ownership, index/body consistency and writing procedure.

## Plan and Completion Boundaries

- `update_plan` only records the decomposition and status of the current task; it does not write project memory or TODO, nor replace them. The project's design plan is `.project-memory/Plan/` — always write that path in full, never a bare `Plan`.
- The completion standard is decided by the user's request; the default delivery is "result implemented, critical path checked, verification evidence recorded, remaining risks stated".
- When a design is added or changed, or a design conflict or problem is found, use the `design-alignment` skill: it settles the design with the user and records the agreed design in `.project-memory/Plan/` before any of it is implemented.

## Code and Configuration Update Rules

- Locate the root cause first; reuse rather than add new abstractions. Logic with branches or side effects must have a check that can be run.
- Do not omit error handling, security, accessibility, data-loss protection or the documentation needed to use or maintain the change; UI must not sacrifice completeness for "conciseness".
- Before changing a public interface, data model, configuration or state flow, check every reference and caller.
- Fix a shared function once, at its common route, after finding all callers.
- New fields must state their source, consumer and default behavior; before deleting or renaming anything, confirm nothing else uses it.
- Comments explain why, not repeat the code; after a migration, removal or refactor, keep only the explanation the final state needs, leaving no old-version narrative or names like `*_no_foo`.
- Never keep unused code, exports or branches; when you remove something, remove it completely, unless the user asks to keep it.
- Add a new dependency only when the standard library and existing dependencies are insufficient.
- Confirm first for permissions, payments, deletion, publishing, external service writes or other high-risk actions; no example may contain keys, tokens, accounts or cookies.
- Do not implement unrequested long-term goals in a single change; every step must produce a verifiable stage result.

## Documentation Lookup Boundary (MUST)

For external libraries, frameworks, SDKs, CLIs, APIs, cloud services or version behavior, never implement from memory when details are uncertain or possibly outdated, an upgrade/migration/deprecation or initialization/tool-invocation change is involved, or the user asks to search or verify. Check official documentation first; look up one or two interfaces directly, and use the `docs-research` skill for three or more or a complex migration.

## Git Commits

Commit only when the user explicitly asks to commit/save changes, and use the `git-commit` skill.

## TODO and Plan

- `.project-memory/TODO/TODO.md` is the user-maintained todo list; read and modify its entries only when the user explicitly asks to write or update TODO. Ordinary tasks must not add or update TODO.
- `.project-memory/Plan/` records the designs and plans the project has settled on — the design it is meant to have, including what is not implemented yet. Only a design the user has agreed to is written there: never a candidate option, an unapproved request or a still-open decision. The main model, `draft-long-term-plan` and `design-alignment` write it; `update-memory` does not, and `collect-update-memory` may only repair its format and topic boundaries, never the designs it records.
- Every design unit in `Plan/` carries a status marker on its heading: `[ ]` not implemented, `[-]` in progress, `[x]` implemented and verified. Flip the marker as the work lands, and never delete an entry because it was implemented.
- Once a design is implemented and verified, write the fact it produced with `update-memory` into the matching fact topic — `Design` for the code's design — and leave the `Plan/` entry in place. A design that is rejected or cancelled has its `Plan/` entry removed and writes no fact.
- If the user says "continue with the todos" without naming an item, ask which one to work on first based on `TODO/TODO.md` and the `Plan/` index, and give a recommendation.

---

<!-- sync-project-config:custom-prompts -->

**Add custom prompts below this note.** Everything above it is managed and replaced on every sync — do not edit or delete it.

---
