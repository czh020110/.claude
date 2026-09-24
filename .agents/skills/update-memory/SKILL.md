---
name: update-memory
description: Process current-task memory candidates using the shared evidence and topic rules.
---

# update-memory

Process eligible memory candidates identified in the current task under the rules in `AGENTS.md`, then write them into project memory.

## Write Scope

- Process only candidates identified by the applicable `AGENTS.md` trigger or final review. Use the shared format reference for eligibility, evidence, topic ownership and placement; do not search unrelated conversation history for more candidates.

## Boundaries

- Executed by the main model personally; do not call a subagent, and do not create a git commit.
- Do local updates only; do not scan the whole project or read unrelated topics.
- Do not maintain `.project-memory/Plan/`, `.project-script/` or `.project-memory/Documents/`; the design the project is meant to have belongs to `draft-long-term-plan` and `design-alignment`, verification scripts to `post-verify`, and user document indexes to `collect-update-memory`.
- Write only current facts and reusable execution lessons; do not write passwords, tokens, private keys, cookies, candidate options, one-off tool errors, transient failures or change logs.

## `.project-memory/` File Responsibilities

- `MEMORY.md` in each topic directory only indexes and routes reads; it never holds fact bodies; index links must point to existing sub-topic files.
- Sub-topic `.md` files in each topic directory record only current facts or reusable execution lessons within that topic's scope, and each fact keeps a single authoritative location.

## Update Process

1. Process the candidate identified by the applicable `AGENTS.md` trigger or final review. Check it against the shared memory format's evidence and exclusion rules; if it does not qualify, stop without writing.
2. Decide which topic the fact belongs to: `Commands`, `Environment`, `Target`, `Design`, `Boundary`, `Preferences`, `Tools` or `Pitfalls`.
3. Read that topic's `MEMORY.md` index and read only the relevant bodies per the index; do not read unrelated topics.
4. **Before the first write or any structural change**, read [project-memory-format.md](references/project-memory-format.md) and follow its fact ownership, indexing and split rules.
   If the reference file is temporarily not visible, at minimum keep this: `MEMORY.md` contains only indexes, bodies and indexes are one-to-one, and each fact keeps a single authoritative location; continue with the existing format and state the risk in the result.
5. Follow the shared format spec's evidence, placement and naming rules. Prefer updating an existing body; create a new one only when a reader would fetch it on its own rather than as part of an existing body, and update the index in the same change.
6. If a body is moved, split, merged or deleted, update its `MEMORY.md` in the same change. When only the content changed and responsibilities did not, the index does not need updating.
7. At the end, check that the topics touched have index/body one-to-one correspondence, valid links, no outdated duplicates, and no child name that merely repeats the parent topic's granularity; if there is no fact to write, do not modify files.

## Memory Topic Routing

Topic ownership, per-topic content rules, the detailed format, split/merge conditions and initialization rules are all defined in `references/project-memory-format.md` — read it and follow it; do not restate those rules here.
