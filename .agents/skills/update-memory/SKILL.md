---
name: update-memory
description: Write a confirmed project fact — implemented, or declared by the user — into project memory.
---

# update-memory

Write only confirmed facts and reusable execution lessons into project memory.

## Write Scope

- Count as project facts, and write into the matching topic: implemented behavior, configuration, environment, commands, tools and design, resting on code, configuration, diffs or verification results; and project purpose, scope, boundaries, constraints and project-scoped preferences, resting on the user's explicit statement or approval. A preference that would hold in every project is not a project fact — it belongs in the user-level memory. `Design` describes code that exists; a design decision that is not implemented yet is not a fact and goes to `.project-memory/Plan/`.
- Execution lessons confirmed during the task that may recur and can be generalized into applicable scenarios, detection signals and avoidance steps may be written into `Pitfalls`.

## Boundaries

- Executed by the main model personally; do not call a subagent, and do not create a git commit.
- Do local updates only; do not scan the whole project or read unrelated topics.
- Do not maintain `.project-memory/Plan/`, `.project-script/` or `.project-memory/Documents/`; the design the project is meant to have belongs to `draft-long-term-plan` and `design-alignment`, verification scripts to `post-verify`, and user document indexes to `collect-update-memory`.
- Write only current facts and reusable execution lessons; do not write passwords, tokens, private keys, cookies, candidate options, one-off tool errors, transient failures or change logs.

## `.project-memory/` File Responsibilities

- `MEMORY.md` in each topic directory only indexes and routes reads; it never holds fact bodies; index links must point to existing sub-topic files.
- Sub-topic `.md` files in each topic directory record only current facts or reusable execution lessons within that topic's scope, and each fact keeps a single authoritative location.

## Update Process

1. Execute once a trigger condition is met — inside a modification task, after that task's verification has passed; first confirm the content is a current fact or reusable execution lesson. If it is neither, stop this skill.
2. Decide which topic the fact belongs to: `Commands`, `Environment`, `Target`, `Design`, `Boundary`, `Preferences`, `Tools` or `Pitfalls`.
3. Read that topic's `MEMORY.md` index and read only the relevant bodies per the index; do not read unrelated topics.
4. **Before the first write or any structural change**, read [project-memory-format.md](references/project-memory-format.md) and follow its fact ownership, indexing and split rules.
   If the reference file is temporarily not visible, at minimum keep this: `MEMORY.md` contains only indexes, bodies and indexes are one-to-one, and each fact keeps a single authoritative location; continue with the existing format and state the risk in the result.
5. Base implemented facts on the current code, configuration, scripts, diffs and verification results; base declared facts on the user's explicit statement. Prefer updating an existing body; create a new one only when a reader would fetch it on its own rather than as part of an existing body, and update the index in the same change.
6. If a body is moved, split, merged or deleted, update its `MEMORY.md` in the same change. When only the content changed and responsibilities did not, the index does not need updating.
7. At the end, check that the topics touched have index/body one-to-one correspondence, valid links, and no outdated duplicates; if there is no fact to write, do not modify files.

## Memory Topic Routing

Topic ownership, per-topic content rules, the detailed format, split/merge conditions and initialization rules are all defined in `references/project-memory-format.md` — read it and follow it; do not restate those rules here.
