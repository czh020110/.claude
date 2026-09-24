---
name: collect-update-memory
description: Use only when the user asks for a staged or full project memory sync; delegates to the collect_update_memory agent.
---

# collect-update-memory

This is the orchestration entry for a "full memory sync"; use `update-memory` for everyday local facts.

## Execution Order

1. If the user also asks for a commit, call the `git-commit` skill first; after the commit completes, use the new HEAD as the base information.
2. Otherwise create no commit. Read `.cache/collect-update-memory-base-commit` under the current platform's Skill directory; if it does not exist, initialize the cache with the current HEAD and mark it "first run, no base", then compare against the current HEAD.
3. Decide the update mode (initialization/update) from whether core planning files such as Boundary and Target are still empty templates; do not decide the initialization scope for the agent. Read `git status --short` and pass the update mode, base commit, current HEAD, whether incremental commits exist, local uncommitted changes, known files/facts and user background to the single `collect_update_memory` agent. Do not scan or search the code to fill out the prompt.
4. The agent must sync incremental commits first, then local uncommitted changes; even with no new commits, the uncommitted-change check cannot be skipped. Once the incremental or local stage succeeds, refresh the base cache to the current HEAD; do not refresh on failure.
5. After the agent returns, relay to the user the actual modifications, index sync, incremental/local sync and verification results.

## Agent Boundaries

- Delegate only to `collect_update_memory`; do not switch to another agent; the skill itself does not scan or modify memory bodies.
- The agent syncs only current facts in `.project-memory/`, and does not touch `TODO/`, `Pitfalls/`, `.project-script/`, code or configuration, and creates no commits; it may read relevant bodies and existing verification scripts. In `Plan/` it may repair the format and the topic boundaries only — never the designs and plans recorded there.
- When there is no fact that needs persisting, the agent may return "no changes needed".
