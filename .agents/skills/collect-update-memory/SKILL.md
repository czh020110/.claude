---
name: collect-update-memory
description: Use only when the user asks for a staged or full project memory sync; delegates to the collect_update_memory agent.
---

# collect-update-memory

This is the orchestration entry for a "full memory sync"; use `update-memory` for everyday local facts.

## Execution Order

1. If the user also asks for a commit, defer `git-commit` until the memory agent's two phases complete. Otherwise create no commit.
2. Always read `.cache/collect-update-memory-base-commit` under the current platform's Skill directory; if it does not exist, initialize the cache with the current HEAD and mark it "first run, no base", then compare against the current HEAD.
3. Read `git status --short` and pass only the base commit, current HEAD, and whether incremental commits or local uncommitted changes exist to the single `collect_update_memory` agent. Do not pass changed-file lists, facts, diffs or source-derived background. The agent must complete its memory-only structural phase before inspecting any code or diff.
4. The agent first audits and, if needed, restructures memory topics without changing body facts. Only after that phase succeeds may it sync incremental commits first, then local uncommitted changes. Even with no new commits, the uncommitted-change check cannot be skipped. Once the incremental or local stage succeeds, refresh the base cache to the current HEAD; do not refresh on failure. If a commit was requested, run `git-commit` after the agent succeeds and refresh the cache again to the new HEAD.
5. After the agent returns, relay to the user the actual modifications, index sync, incremental/local sync and verification results.

## Agent Boundaries

- Delegate only to `collect_update_memory`; do not switch to another agent; the skill itself does not scan or modify memory bodies.
- The agent's first phase proactively checks topic boundaries and index/body structure across `.project-memory/` using only the memory-format spec, indexes and bodies. It may move, split, merge, rename or create topic bodies when the spec supports the change; body content must remain verbatim during this phase, and index edits are limited to routing the new structure. It does not inspect code or diffs until this phase is complete. In the second phase it syncs current facts from commits and local changes. It does not touch `TODO/`, `.project-script/`, code or configuration, and creates no commits. `Plan/` designs may never be changed, reworded or deleted; `Pitfalls/` may be restructured in phase one but is not fact-synced in phase two.
- When there is no fact that needs persisting, the agent may return "no changes needed".
