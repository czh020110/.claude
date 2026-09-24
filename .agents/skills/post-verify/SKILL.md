---
name: post-verify
description: "Final verification gate: run once, after all edits of a modification task are done and before delivery."
---

# post-verify

## Execution Flow (MUST)

### 1. Read the verification script index first

Check `.project-script/MEMORY.md` first; if it does not exist, create it per the later steps (see step 4).

### 2. Determine the verification scope

Scope the verification to the files this task changed and what they affect — unchanged, unrelated code needs no verification:

- Added/modified/deleted source code, scripts, configuration, templates and docs (must be checked when replacement rules or path references are involved).
- Downstream objects affected by the change: callers, interfaces, data flows, pages, etc.

Answer two questions, not just "did the last command pass":

- **Does the change do what was asked?** Every requirement of this task is met, project constraints are respected, and nothing is missing.
- **Is the change correct?** It has no errors, and nothing it touches is broken.

### 3. Execute or reuse verification

Choose in order of priority:

1. **Reuse an existing verification script**: when `MEMORY.md` has a script matching this change, run it with the entry command recorded in the index.
2. **Verify with existing commands**: with no dedicated script, run the applicable checks from the coverage list below with existing commands.
3. **Create a reusable script**: for logic with branches or side effects, or for interface, configuration, data flow, page or security-related changes, with no suitable existing script, create one in `.project-script/<verification-type>/`.

What verification scripts need to cover includes but is not limited to:

1. Code logic: run the relevant test script or a minimal reproduction command.
2. Type/API: run type checks, interface tests or import checks.
3. Frontend pages: start them and look at the critical path yourself; if it cannot be viewed, explain why.
4. Configuration changes: verify the configuration is read correctly.
5. Doc/template changes: search for old project-bound words and check that referenced paths exist.

### 4. Manage the verification script index

When adding, deleting, moving or renaming a reusable script, update `.project-script/MEMORY.md` in the same change.

- `.project-script/MEMORY.md` records only the script path, purpose, applicable scenarios, entry command and necessary prerequisites; it does not copy the script body.
- Reusable scripts go in `.project-script/<verification-type>/`; do not pile them at the root.
- When there is no reusable script, do not create an empty script subdirectory or a fake index entry.
- Verification scripts may read credentials only from environment variables or other secure configuration, and must never store API keys, tokens or cookies.

### 5. Fix loop

When verification finds problems, fix the code and re-verify until it passes or the remaining problems are confirmed not to block delivery. Do not end the task with verification incomplete or unexplained.

### 6. Report the verification result

Report to the user:

- Which verifications were run and what the results were.
- Whether a verification script and its index were created or updated.
- If verification could not be run, explain the reason and the alternative check results.

## Boundaries
- For a simple, low-risk one-line change, static or diff checks are enough; you are not required to add a new verification script. "No tests needed" means no new test script, not that verification can be skipped.
