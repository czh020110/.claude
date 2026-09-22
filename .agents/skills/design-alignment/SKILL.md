---
name: design-alignment
description: Use when a design is added, changed, or found to conflict: settles it with multi-round request_user_input, then records the plan in Pending.
---

# design-alignment

Settles a design with the user before any of it is implemented — a new design, a change to an existing one, or a conflict or problem found in the current design. The result is one agreed plan recorded in `.project-memory/TODO/Pending.md`.

## Trigger Boundary

Use this skill when any of these happens:

- the user proposes a new design, or a change to an existing one;
- the design conflicts with the current implementation, with another design, or with an effective constraint;
- the design looks wrong, risky or infeasible.

Do not use it for a mechanical decision (naming, formatting, file layout) or when the user has already settled the design and only wants it implemented.

## Process

1. **Understand the design before judging it.** Read the relevant `.project-memory/` bodies and the code it touches, so the discussion rests on the current state rather than on memory of it.
2. **Judge it yourself, honestly.** Work out what the design changes, what it conflicts with, what it costs and whether it is feasible. When feasibility depends on an external library, framework, SDK, API or version behaviour, follow the Documentation Lookup Boundary in `AGENTS.md`: check the official documentation instead of guessing.
3. **Never treat a design as correct because the user proposed it.** If it looks wrong, risky or infeasible, say so with the reason and put the better option forward — agreement is not a service.
4. **Ask with `request_user_input`, never with open prose.** Every round offers 2–4 concrete options and marks exactly one of them **(Recommended)** — put it first, and it is the option you would pick. Do not ask the user to supply details in free text; turn the open question into options first.
5. **Iterate until the plan is unambiguous.** Each round narrows what is still open; run as many rounds as it takes. The design counts as confirmed only once every open point is settled and the plan can be stated in a few sentences with no "or" left in it.
6. **Record the confirmed plan in `.project-memory/TODO/Pending.md`** as one entry with background, the decision, completion criteria and related scope. A confirmed design that is not implemented yet stays in Pending and is not written into fact memory.
7. **Then implement it**, or hand back to the task that raised it. Once the design is implemented and verified, its Pending entry is removed and the fact is written with `update-memory`.

## Boundaries

- A design is confirmed only when the user has agreed to it. Never record a plan you inferred, and never treat your own recommendation as the decision.
- The options must be real alternatives — different in approach, not in wording. When there is genuinely only one option, say so and ask whether to proceed instead of inventing a second.
- Do not change the design memory, or the code of the design under discussion, before the user has confirmed the plan.
- If the environment cannot interact, make the most conservative assumption, say so in the result, and do not record the plan in Pending as confirmed.
