---
name: draft-long-term-plan
description: Use only when the user explicitly asks to draft or extend the project's long-term design plan; never start it on your own.
---

# draft-long-term-plan

Builds and extends `.project-memory/Plan/` — the design the project is meant to have, from its start to its final form, including the parts that are not built yet.

## Trigger Boundary

Start this skill only when the user asks for it: to design the project, to plan a new part of it, or to write the plan down. Never start it because a task looks large, because the project has no plan yet, or because a design discussion just happened — an existing design that changed belongs to `design-alignment`.

## Two Modes

- **Greenfield** — the repository has no code yet: design the whole project, from zero to final delivery.
- **Incremental** — the repository already has code: read `.project-memory/Design/` and the code it points at first, take what is already built as given, and design only what is still to come. Never restate implemented design in `Plan/`.

## Process

1. **Ask the user to describe the project, once, in their own words** — what it is for, what it should do, who uses it. This is the only open question in the flow; everything after it is options.
2. **Decompose before asking anything else.** Turn that description into the parts the project is made of, and read the list back in a few lines so the user can correct the shape before the detail starts.
3. **Settle every part's design before touching technology.** Go part by part: what it does, what the user sees, what it must not do. Ask with `request_user_input`, 2–4 concrete options per round, exactly one marked **(Recommended)** and placed first — the same rule `design-alignment` uses. Run as many rounds as it takes; do not move past a part that still has an "or" in it.
4. **Only once every functional part is settled, ask about technology** — libraries, frameworks, SDKs, APIs and specific versions, part by part. Where the user names something, fix it. Where nothing is named, choose a sensible default, say which you chose and why, and keep it consistent across parts.
5. **Reach the final delivery.** The design covers the whole architecture from the start to the project's finished form, not just the first module. Stop only when the user says the design is complete.
6. **Write it into `.project-memory/Plan/`** — one body per design topic plus the index — and report which topics were created or extended.

## Writing Rules

- Follow the index and body rules in `references/project-memory-format.md` under the current platform's `update-memory` Skill directory: `Plan/MEMORY.md` is an index only, bodies and index are one-to-one, and two topics must not cover the same or a similar subject. Read that reference before the first write.
- A body is a design document, not a task list: architecture, module boundaries, interfaces, data shapes, the technology in use and the reasons behind each choice. It may go as fine as per-function or per-interface design.
- **Every design unit carries a status marker on its heading** — `[ ]` not implemented, `[-]` in progress, `[x]` implemented and verified. Anything written now starts as `[ ]`. Never delete an entry for being implemented; flip the marker instead.
- Record only what the user has agreed to. A default you chose is written as the design with its reason, not as an open question.
- Do not write current facts: `Design/`, `Target/`, `Boundary/`, `Commands/` and the rest belong to `update-memory`.
- Do not create empty files, and do not write into `TODO/TODO.md`.

## Boundaries

- User-invoked only. The agent never starts this skill on its own initiative.
- Never treat your own recommendation as the user's decision, and never write a design the user has not agreed to.
- This skill designs and records; it does not build the design. Implementing it is a separate task.
- If the environment cannot interact, stop and report what is still open instead of writing a plan you inferred.
