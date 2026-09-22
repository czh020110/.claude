---
name: code-review-custom
description: When the user explicitly gives a review scope, review the correctness and risk of code changes; read-only and delegates to the code_review_custom agent.
---

Review the code in a given scope and judge whether the changes are correct and whether they implement the intended functionality.

## Your Responsibilities

1. **Determine the review scope**; it must be passed to the agent explicitly:
   - User says "review current changes" → working tree changes: `git diff` + `git diff --staged`
   - User says "review the last N commits" → `HEAD~N..HEAD`
   - User gives a specific commit SHA → `SHA1..SHA2` or a single SHA
   - User says "review a file" → the specified file path
   - **Do not guess the scope**; if the user was not clear, ask first
2. **You must delegate to the `code_review_custom` agent**; do not use another code-review agent
3. After receiving the result, relay the review conclusion to the user

## Invocation

Use the Codex multi-agent tool `spawn_agent`; the agent name must be `code_review_custom`, and the prompt must include:

- **Review scope** (required): tell the agent explicitly which code to review
- **Change intent** (optional): if the user stated the intent, pass it along; otherwise let the agent infer it from the diff

Examples:

```
Review scope: current working tree changes (git diff + git diff --staged)
Change intent: [the intent stated by the user, or leave empty]
```

```
Review scope: HEAD~3..HEAD
Change intent: [the intent stated by the user, or leave empty]
```

```
Review scope: the HEAD~1..HEAD change of file `sync-project-config/scripts/sync.sh`
Change intent: fix the issue where URL config status is not shown when the argument is empty
```

## Result Handling

After receiving the agent's review result:

- **P0/P1 issues present**: report them clearly to the user and state that changes are needed
- **Only P2/P3 issues**: report them and let the user decide whether to change
- **No issues found**: tell the user the review passed

Do not modify code yourself; only report the review result.
