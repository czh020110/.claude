---
name: update-memory
description: Use only when this round confirmed an implemented and verifiable project fact, effective constraint, preference, environment, command, or a reusable execution lesson.
---

# update-memory

Write only facts and reusable execution lessons that are currently adopted, implemented and verifiable into project memory. Do not invoke this skill when there are no such facts.

## Write Scope

- Only behavior, configuration, constraints, environment, commands and long-term preferences that are implemented and have verification evidence count as project facts and may be written into the matching topic; execution lessons confirmed during execution that may recur and can be generalized into applicable scenarios, detection signals and avoidance steps may be written into `Pitfalls`.

## Boundaries

- Executed by the main model personally; do not call a subagent, and do not create a git commit.
- Do local updates only; do not scan the whole project or read unrelated topics.
- Do not maintain `.project-script/` or `.project-memory/Documents/`; verification scripts are managed by `post-verify`, and user document indexes are synced by `collect-update-memory`.
- Write only currently verifiable facts and reusable execution lessons; do not write passwords, tokens, private keys, cookies, candidate options, one-off tool errors, transient failures or change logs.

## `.project-memory/` File Responsibilities

- `MEMORY.md` in each topic directory only indexes and routes reads; it never holds fact bodies; index links must point to existing sub-topic files.
- Sub-topic `.md` files in each topic directory record only current facts or reusable execution lessons within that topic's scope, and each fact keeps a single authoritative location.
- `Commands`, `Environment`, `Target`, `Design`, `Boundary`, `Tools` and `Pitfalls` are memory directories this skill may update by topic routing; `Documents` bodies are read-only by default and are not modified by this skill.
- When a topic is created, deleted, renamed, moved, split or merged, the corresponding `MEMORY.md` must be synced in the same round; when only body content is corrected and responsibilities are unchanged, there is no need to mechanically update the index.

## Trigger Conditions

Use it immediately when any of the following is confirmed in conversation or execution: user preferences/constraints already in effect, implemented design or boundary, an actual change in a long-term stage, environment facts, reusable commands/tools, reusable execution lessons, or discovered conflicts between memory and the current state. Temporary speculation and single results are not written.

## Update Process

1. Execute immediately once a trigger condition is met; first confirm the content is a current fact or reusable execution lesson. If it is neither, stop this skill.
2. Decide which topic the fact belongs to: `Commands`, `Environment`, `Target`, `Design`, `Boundary`, `Tools` or `Pitfalls`.
3. Read that topic's `MEMORY.md` index and read only the relevant bodies per the index; do not read unrelated topics.
4. **Before the first write or any structural change**, read [project-memory-format.md](references/project-memory-format.md) and follow its fact ownership, indexing and split rules.
   If the reference file is temporarily not visible, at minimum keep this: `MEMORY.md` contains only indexes, bodies and indexes are one-to-one, and each fact keeps a single authoritative location; continue with the existing format and state the risk in the result.
5. Base everything on the current code, configuration, scripts, diffs and verification results: prefer updating existing bodies with clear semantics; create a new body only when it forms an independent read unit, and update the index in the same round.
6. If a body is moved, split, merged or deleted, atomically update the corresponding `MEMORY.md`; when only content is corrected and responsibilities are unchanged, there is no need to mechanically update the index.
7. At the end, check that the topics touched this round have index/body one-to-one correspondence, valid links, and no outdated duplicates; if there is no fact to write, do not modify files.

## Memory Topic Routing

- `Commands`: install, run, build, test, evaluate, deploy and recover.
- `Environment`: tools/versions, hardware, paths, variables, external services and platform limits.
- `Target`: currently effective project purpose, scope and acceptance criteria.
- `Design`: current architecture, module responsibilities, collaboration model and design rationale.
- `Boundary`: behavior that must be preserved, out-of-scope items, limits and quality floor.
- `Tools`: reusable helper scripts, visualizations, statistics or data conversion tools.
- `Pitfalls`: confirmed execution lessons that may recur, applicable scenarios, detection signals, root cause and avoidance steps; do not record one-off errors or raw logs.

Detailed format, split/merge conditions, initialization rules and topic ownership are in `references/project-memory-format.md`.
