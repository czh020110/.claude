# Project Memory and Workflow Constraints

This repository's long-term project memory lives in `.project-memory/`. Memory uses an "index + chunked body" layout: each topic's `MEMORY.md` only routes, and fact bodies are read on demand.

## Task Routing

- Every new task first uses `read-index-memory` to read all topic indexes, then reads only the bodies relevant to the task.
- Pure consultation, code review, or external research does not enter the modification loop; the memory-reading, documentation-lookup and output constraints still apply.
- Adding, fixing, refactoring, configuration, tests, docs or prompt syncs are "modification tasks" and follow the loop below.
- `.project-memory/TODO/TODO.md` is the user-maintained todo list; read and modify its entries only when the user explicitly asks to write or update TODO. If the user only says "continue with the todos" without specifying what to write, ask first; ordinary tasks must not add or update TODO.
- When discussing not-yet-implemented plans, architecture, boundaries or implementation decisions, the main model records them directly in `.project-memory/TODO/Pending.md` and does not call `update-memory`; such content must not be written into project fact memory until it is implemented and verified.

## Modification Task Loop (MUST)

### 1. Before modifying

- Read the project memory bodies relevant to the current task and confirm the project boundary, target, design and effective constraints.
- Identify the modification entry point, callers/callees, the affected data or state flow, and the available verification methods.

### 2. Execution

- Use `update_plan` only when the task really has more than three interdependent steps, multiple independent decisions, or otherwise complex decomposition; update it with actual progress and mark completed steps immediately. A plan does not replace TODO/Pending.
- When external libraries, frameworks, SDKs, CLIs, APIs, cloud services or version behavior are involved, check the official documentation first: one or two interfaces can be looked up directly; three or more, or a complex migration, uses the `docs-research` skill.
- Reuse existing implementations and project conventions; make the smallest change that achieves the goal; prefer the standard library or existing dependencies; do not refactor unrelated code along the way, and do not drop requirements or change unrequested behavior for the sake of brevity.
- Keep going on complex tasks until "implemented, results checked, found problems fixed, verification complete" are all done; do not stop early just because the first version is implemented, unless a safety boundary genuinely needs a user decision.

### 3. Verification

- Every completed modification task (including configuration, templates, docs and prompts) must run the `post-verify` skill.
- Prefer reusing the verification entry points in `.project-script/MEMORY.md`; when no script matches, do targeted static checks, type/API checks or tests. When adding a reusable verification script, put it in `.project-script/<verification-type>/` and sync the index.
- Fix problems found and re-run the affected verification; if it cannot be run, state the reason and the alternative evidence, and never write unverified content as passed.

### 4. Memory consolidation
- Memory consolidation starts when information is confirmed during execution to have long-term reuse value, not at a staged sync, commit, or task end.
- Once any of the following holds, the main model must immediately use the `update-memory` skill:
  - Current behavior, configuration, design, boundary, environment, commands or user preferences have been implemented/taken effect, with code, configuration or verification evidence;
  - A reusable execution lesson was confirmed during execution that may recur in later tasks and can be abstracted into applicable scenarios, detection signals and avoidance steps;
  - Existing memory is found to conflict with the current implementation or effective constraints and the facts need correcting.
- Do not call `update-memory` when the trigger conditions are not met: single results, temporary speculation, one-off tool errors, transient environment failures, raw debug details and unimplemented plans are not consolidated.

## Plan and Completion Boundaries

- `update_plan` only records the decomposition and status of the current task; it does not write project memory or TODO.
- The completion standard is decided by the user's request; the default delivery is "result implemented, critical path checked, verification evidence recorded, remaining risks stated".
- When a task spans a long-term stage, first split it into verifiable stages and update `.project-memory/TODO/STEP.md`; do not proactively design a full history table for an empty template, and one-off tasks are not written into STEP. If the long-term direction changes at the same time, complete user confirmation as described in the next item.
- When long-term design, boundary or stage direction changes are needed, first analyze the conflicts and risks against the current state, then use `request_user_input` (multiple rounds if needed) to ask the user to confirm; do not change the corresponding design memory before confirmation. If the current environment cannot interact, adopt the minimum safe assumption and state it explicitly in the result.

## Code and Configuration Update Rules

- Locate the root cause first; reuse rather than add new abstractions. Non-trivial logic must have a runnable check.
- Do not omit error handling, security, accessibility, data-loss protection or necessary documentation; UI must not sacrifice completeness for "conciseness".
- Before changing a public interface, data model, configuration or state flow, check all references and callers; for shared functions, find all callers first and fix them once at the common route; field meaning in shared structures must be clear, new fields must state their source, consumer and default behavior, and deleting/renaming must first confirm nothing is missed.
- Comments explain why, not repeat the code; after a migration, removal or refactor, keep only the explanation the final state needs, leaving no old-version narrative or names like `*_no_foo`.
- Confirm first for permissions, payments, deletion, publishing, external service writes or other high-risk actions; no example may contain keys, tokens, accounts or cookies.
- Do not implement unrequested long-term goals in one shot; every step forward must produce a verifiable stage result.

## Documentation Lookup Boundary (MUST)

Never implement from memory in these cases: an interface is uncertain or suspected outdated, version upgrade/migration/deprecation, API/SDK initialization or tool invocation changes, or the user asks to search or verify. Prefer `context7`; if that tool is unavailable or the results are insufficient, check the official web page; mark uncertain items explicitly.

## Git Commits

Commit only when the user explicitly asks to commit/save changes, and use the `git-commit` skill. Do not create a commit without an explicit request.

## TODO and Pending

- `TODO.md` is the user-maintained todo list; the main model may modify it only when the user explicitly asks to write or update it, and must not add todos proactively.
- When discussing not-yet-implemented plans, architecture, boundaries or implementation decisions, the main model writes them directly into `Pending.md` and does not call `update-memory`; such content must not be written into project fact memory until it is implemented and verified. Maintained by the main model only.
- After a Pending item is implemented and verified, remove its entry, then use `update-memory` per the consolidation trigger conditions to write the final fact; if a plan is cancelled, only remove the entry.
- Rejected Pending items must also have their entries removed.
- Both files use only checkboxes: `[ ]` not started, `[-]` in progress, `[x]` done.
- If the user says "continue with the todos/plans" without specifying an item, ask which one to work on first based on the contents of both files and give a recommendation.

---

<!-- sync-project-config:custom-prompts -->

**Do not remove the marker above.** Everything above it is managed and replaced on every sync; append project-specific prompts below it.

---
