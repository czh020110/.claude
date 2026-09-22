# Project Memory and Workflow Constraints

This repository's long-term project memory lives in `.project-memory/`. Memory uses an "index + chunked body" layout: each topic's `MEMORY.md` only routes, and fact bodies are read on demand.

## Task Routing

- Every new task first uses `read-index-memory` to read all topic indexes, then reads only the bodies relevant to the task.
- Pure consultation, code review, or external research does not enter the modification loop; the memory-reading, documentation-lookup and output constraints still apply.
- Adding, fixing, refactoring, configuration, tests, docs or prompt syncs are "modification tasks" and follow the loop below.

## Modification Task Loop (MUST)

### 1. Before modifying

- Read the project memory bodies relevant to the current task and confirm the project boundary, target, design and effective constraints.
- Identify the modification entry point, callers/callees, the affected data or state flow, and the available verification methods.

### 2. Execution

- Use `update_plan` only when the task really has more than three interdependent steps, multiple independent decisions, or otherwise complex decomposition; update it with actual progress and mark completed steps immediately.
- When external libraries, frameworks, SDKs, CLIs, APIs, cloud services or version behavior are involved, follow the Documentation Lookup Boundary below.
- Reuse existing implementations and conventions; make the smallest change that works; prefer the standard library or existing dependencies; do not refactor unrelated code, drop requirements, or change behavior that was not asked for.
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

- `update_plan` only records the decomposition and status of the current task; it does not write project memory or TODO, nor replace them.
- The completion standard is decided by the user's request; the default delivery is "result implemented, critical path checked, verification evidence recorded, remaining risks stated".
- When a task spans a long-term stage, split it into verifiable stages and update `.project-memory/TODO/STEP.md`; do not design a full history table for an empty template, and one-off tasks are not written into STEP. If the long-term direction changes too, get the user's confirmation first (see the next item).
- When long-term design, boundary or stage direction changes are needed, analyze the conflicts and risks first, then ask the user to confirm with `request_user_input` (multiple rounds if needed); do not change the design memory before that confirmation. If the environment cannot interact, make the most conservative assumption and say so in the result.

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

Never implement from memory in these cases: an interface is uncertain or suspected outdated, version upgrade/migration/deprecation, API/SDK initialization or tool invocation changes, or the user asks to search or verify.

When external libraries, frameworks, SDKs, CLIs, APIs, cloud services or version behavior are involved, check the official documentation first: one or two interfaces can be looked up directly; three or more, or a complex migration, uses the `docs-research` skill. Prefer `context7`; if that tool is unavailable or the results are insufficient, check the official web page; mark uncertain items explicitly.

## Git Commits

Commit only when the user explicitly asks to commit/save changes, and use the `git-commit` skill.

## TODO and Pending

- `.project-memory/TODO/TODO.md` is the user-maintained todo list; read and modify its entries only when the user explicitly asks to write or update TODO. Ordinary tasks must not add or update TODO.
- When discussing not-yet-implemented plans, architecture, boundaries or implementation decisions, the main model writes them directly into `.project-memory/TODO/Pending.md` and does not call `update-memory`; such content must not be written into project fact memory until it is implemented and verified. Maintained by the main model only.
- After a Pending item is implemented and verified, remove its entry, then use `update-memory` per the consolidation trigger conditions to write the final fact; if a plan is rejected or cancelled, only remove the entry.
- Both files use only checkboxes: `[ ]` not started, `[-]` in progress, `[x]` done.
- If the user says "continue with the todos/plans" without specifying an item, ask which one to work on first based on the contents of both files and give a recommendation.

---

<!-- sync-project-config:custom-prompts -->

**Add custom prompts below this note.** Everything above it is managed and replaced on every sync — do not edit or delete it.

---
