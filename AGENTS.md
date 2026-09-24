# Project Memory and Workflow Constraints

This repository's long-term project memory lives in `.project-memory/`. Memory uses an "index + chunked body" layout: each topic's `MEMORY.md` only routes, and fact bodies are read on demand.

## Task Routing

- Every new task first uses `read-index-memory` to read all topic indexes, then reads only the bodies relevant to the task; a task that touches an area designed but not built yet also reads that `Plan/` body.
- Pure consultation, code review, or external research does not enter the modification loop; the memory-reading, documentation-lookup and output constraints still apply.
- Adding, fixing, refactoring, configuration, tests, docs or prompt syncs are "modification tasks" and follow the loop below.

## Memory Capture

- Across all tasks, trigger `update-memory` when a durable project goal, scope, preference or boundary is explicitly stated; do not wait for task completion or technical verification.
- Stable implicit project preferences or boundaries may also trigger capture as soon as the signal recurs across separate task contexts without a contrary correction; do not wait for task completion or technical verification. `update-memory` handles their evidence and inference label.
- Immediately after `post-verify` passes, perform one final memory review before delivery: inspect the completed work for implementation-derived facts, conflicts with existing memory, and execution lessons with confirmed recurrence risk and reusable conditions; record eligible findings with `update-memory`.
- This final review does not delay eligible explicit or inferred preferences and boundaries; record them when they become clear. Do not record temporary progress, unresolved proposals or unsupported technical claims.

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

- After verification passes, complete the final memory review described in `Memory Capture` before delivery.

## Plan and Completion Boundaries

- `update_plan` only records the decomposition and status of the current task; it does not write project memory or TODO, nor replace them. The project's design plan is `.project-memory/Plan/` — always write that path in full, never a bare `Plan`.
- The completion standard is decided by the user's request; the default delivery is "result implemented, critical path checked, verification evidence recorded, remaining risks stated".
- Trigger `design-alignment` before implementation when a new design or design change still needs user agreement; when an existing design conflicts with the current implementation, another design, an effective constraint or `.project-memory/Plan/`; or when a design appears wrong, risky or infeasible and needs a decision. A boundary or preference being recorded as memory alone, a mechanical choice, or implementing an already settled design does not trigger it.

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

- TODO is user-maintained; do not add or change entries unless the user explicitly asks. If the user asks to continue TODOs without naming an item, ask which item to take based on TODO and Plan, and make a recommendation.
- Plan records only settled intended designs, including parts not yet implemented; do not record candidates or unresolved decisions. Use `draft-long-term-plan` only on explicit request; use `collect-update-memory` only on explicit request for a full or staged memory sync. `update-memory` does not edit Plan; `collect-update-memory` may repair its structure only, never its designs.
- Mark each Plan item `[ ]` (not implemented), `[-]` (in progress), or `[x]` (implemented and verified). Keep implemented entries and write the resulting fact to the matching topic (`Design` for code design) after verification. Remove rejected or cancelled designs without writing a fact.

---

<!-- sync-morrowmark:custom-prompts -->

**Add custom prompts below this note.** Everything above it is managed and replaced on every sync — do not edit or delete it.

---
