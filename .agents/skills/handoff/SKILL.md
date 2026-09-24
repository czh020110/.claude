---
name: handoff
description: Review current-session candidates for eligible memory updates, then create a concise continuation prompt. Use for handoffs or session transfers.
---

# handoff

First consolidate any confirmed, reusable long-term facts that belong in memory. Then create a short, actionable handoff prompt that lets a new session continue the current work without making the user repeat the task.

## Workflow

### 1. Review and Consolidate Memory

- Review the current conversation under `update-memory`'s shared eligibility and evidence rules. Do not inspect files, run verification, or use external information to establish memory facts.
- If eligible information exists and memory writing is allowed, use `update-memory` in this step. Respect user and project restrictions; if nothing qualifies, writing is prohibited, or the skill is unavailable, skip memory writing and continue to the handoff.
- If memory writing fails or only partially completes, do not claim all candidate facts were stored. Continue to the handoff and exclude only facts confirmed as successfully persisted.
- Track which facts were actually persisted. Do not include those facts in the handoff, either verbatim or paraphrased. Do not read existing memory to enrich the handoff.
- Do not include credentials or other directly usable secrets in memory or the handoff.

### 2. Draft the Handoff

- Base handoff content only on information explicitly present in the current conversation. Do not read project files, Git state, other sessions, or external sources to fill gaps.
- Distinguish confirmed information from assumptions, unresolved details and unverified claims. Include uncertainty only when it matters to continuation, label it clearly, and never present it as confirmed.
- Include only context needed to resume; omit unrelated completed work, general background and long excerpts. Include exact in-progress text only when it is necessary and unavailable at a known path.

## Output

- Reply with exactly one Markdown fenced code block and no surrounding commentary, so the user can copy it directly into a new session.
- Write the handoff in the user's language and address the receiving agent directly.
- Keep it concise. Use only sections with useful information; do not emit empty headings or placeholders.
- Always state the current task and its status, what remains, and the next concrete action. Distinguish completed work from work that is planned, underway, blocked, or awaiting a user decision. Include known constraints and decisions that the next session must preserve.
- Mention verification or other results only when the current conversation explicitly confirms they happened. Do not claim that work or checks are complete without evidence in the conversation.
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
