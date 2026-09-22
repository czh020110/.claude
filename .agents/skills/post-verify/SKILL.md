---
name: post-verify
description: After finishing code, configuration, template, doc or prompt changes, run the final targeted verification and leave evidence.
---

# post-verify

The final verification entry point after a modification task completes, covering reuse, creation, index sync and the fix loop for verification scripts.

## Trigger Timing (MUST)

All development and modification tasks (add/fix/refactor/config/test/docs/prompt sync) must run this skill after the main modifications of this round are done and before delivery.

- Pure consultation, review and research requests do not need it.
- Tasks that produced no actual file changes do not need it; doc, prompt and agent/skill configuration changes still need targeted verification.
- Intermediate states of an unfinished task do not need it; run it only after the modifications for this round's delivery are complete.

## Execution Flow (MUST)

### 1. Read the verification script index first

Check `.project-script/MEMORY.md` first; if it does not exist, create it per the later steps (see step 4).

### 2. Determine the verification scope

Base it on the files actually modified this time, covering:

- Added/modified/deleted source code, scripts, configuration, templates and docs (must be checked when replacement rules or path references are involved).
- Downstream objects affected by the change: callers, interfaces, data flows, pages, etc.

Do not verify only "the last command"; verify the completeness of the task requirement itself: whether the functionality matches the user's need, whether project constraints are met, and whether anything is missing or wrong.

### 3. Execute or reuse verification

Choose in order of priority:

1. **Reuse an existing verification script**: when `MEMORY.md` has a script matching this change, run it with the entry command recorded in the index.
2. **Verify with existing commands**: with no dedicated script, verify using existing commands such as static checks, diff checks, type checks, import checks or test commands.
3. **Create a reusable script**: for non-trivial logic, interface, configuration, data flow, page or security-related changes with no suitable existing script, create a reusable script in `.project-script/<verification-type>/`.

What verification scripts need to cover includes but is not limited to:

1. Code logic: run the relevant test script or a minimal reproduction command.
2. Type/API: run type checks, interface tests or import checks.
3. Frontend pages: start them and actually view the critical path; if it cannot be viewed, explain why.
4. Configuration changes: verify the configuration is read correctly.
5. Doc/template changes: search for old project-bound words and check that referenced paths exist.

### 4. Manage the verification script index

When adding, deleting, moving or renaming a reusable script, `.project-script/MEMORY.md` must be synced in the same round.

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
- A simple, low-risk one-line change may use static checks, diff checks or existing commands and is not forced to create a new verification script; "no tests needed" only means no dedicated new test script is needed, not that verification can be skipped.
