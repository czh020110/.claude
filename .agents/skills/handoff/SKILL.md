---
name: handoff
description: Consolidate confirmed, reusable long-term facts when permitted, then turn the current session's active work into a concise, copyable continuation prompt. Use when the user asks for a handoff, session transfer, or prompt to continue work elsewhere.
---

# handoff

First consolidate any confirmed, reusable long-term facts that belong in memory. Then create a short, actionable handoff prompt that lets a new session continue the current work without making the user repeat the task.

## Workflow

### 1. Review and Consolidate Memory

- Review only the current conversation to identify candidate memories. Persist only confirmed, reusable, long-term project facts, settled design decisions, or explicitly stated project-scoped preferences and constraints.
- Do not persist temporary task context, current progress, immediate next steps, one-off debugging details, unapproved proposals, assumptions, or unverified claims. Do not investigate or infer facts to make them appear durable. If an item is unverified, leave it out of memory and consider including it in the handoff as unverified when it matters to the next step.
- Only pass facts to `update-memory` when their confirmation or supporting evidence is already present in the current conversation; do not inspect source code, run new verification, or use external information to prove a candidate.
- If eligible facts exist and memory updates are allowed, use the `update-memory` skill and follow its rules. Respect any user instruction or project boundary that prohibits memory writes. If no eligible facts exist, writes are prohibited, or the skill is unavailable, skip memory writing and continue to the handoff.
- If memory writing fails or only partially completes, do not claim all candidate facts were stored. Continue to the handoff and exclude only facts confirmed as successfully persisted.
- Track which facts were actually persisted. Do not include those facts in the handoff, either verbatim or paraphrased. Do not read existing memory to enrich the handoff.
- Do not include credentials or other directly usable secrets in memory or the handoff.

### 2. Draft the Handoff

- Base handoff content only on information explicitly present in the current conversation. Do not read project files, Git state, other sessions, or external sources to fill gaps.
- Separate confirmed facts from assumptions or unresolved details. Never present an inference as confirmed; omit low-value uncertainty and label consequential uncertainty clearly.
- Include only context the next session needs to resume the active task: the goal, current progress, unfinished work, decisions and constraints, blockers, and relevant paths or results when known. Exclude anything already persisted during step 1.
- Do not repeat unrelated completed work, general project background, or large source/text excerpts. Include exact in-progress text only when the next session cannot continue without it and it is not available through a known path.

## Output

- Reply with exactly one Markdown fenced code block and no surrounding commentary, so the user can copy it directly into a new session.
- Write the handoff in the user's language and address the receiving agent directly.
- Keep it concise. Use only sections with useful information; do not emit empty headings or placeholders.
- Always state the current task and its status, what remains, and the next concrete action. Distinguish completed work from work that is planned, underway, blocked, or awaiting a user decision. Include known constraints and decisions that the next session must preserve.
- Mention verification or other results only when the current conversation explicitly confirms they happened. Do not claim that work or checks are complete without evidence in the conversation.
- Keep unverified but task-relevant details in the handoff only, clearly labeled as unverified; never persist them as memory.
- If there are multiple active tasks, list them separately with their own status and next action. Do not revive unrelated tasks that are already complete.
- If an essential detail is missing, state what is unknown and ask the receiving session to clarify only if it blocks progress. Do not invent a next step when none is supported by the conversation.

Suggested structure (adapt or omit sections as needed):

~~~md
# Session Handoff

Continue from the state below. Do not repeat work explicitly marked as complete.

## Current Task
...

## Progress
- Completed: ...
- In progress: ...
- Remaining: ...

## Known Information and Constraints
- ...

## Next Step
1. ...

## Blockers or Open Questions
- ...
~~~
