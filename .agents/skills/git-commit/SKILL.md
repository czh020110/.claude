---
name: git-commit
description: Create a git commit: group the changes by purpose, write the structured message, then verify.
---

# Commit Flow

1. Run `git status --short` and review `git diff` and `git diff --staged` (when the user specifies a scope, use that scope).
2. **Group by modification purpose**. You do not have to put everything into one commit. Judge the purpose from the code changes; when the changes clearly do not belong to a single modification — for example one is a feature implementation and another is an unrelated config fix — split them and commit each group separately. Each commit's short and detailed description covers only its own group; changes with the same purpose stay together, so do not split them artificially.
3. For each group, judge the change type and generate the short commit description: `<type-prefix>: verb + object + purpose`. Prefixes: `feat:` new feature or file; `fix:` bug or incorrect behavior fix; `docs:` only docs/description updates; `test:` add or modify tests; `build:` affects the build system or external dependencies; `refactor:` refactoring that does not change external behavior. Any modification or deletion of code files (source, scripts) disqualifies `docs:`; use `docs:` only when there is no code change at all.
4. Generate each commit's detailed description (commit body) per the format below.
5. Run verification; if it cannot be run, explain why.
6. Create the git commits group by group; **once all commits are done, the working tree (unignored parts) must be clean**. If the commit or verification did not run successfully, state the specific reason; do not just write "not committed / not executed".

# Commit Scope and Behavior

- When the user specifies or excludes a scope, commit strictly within it and do not fall back to "all changed files"; the user's request takes priority over the default.
- When the working tree (unignored) contains parts that clearly should not be committed (local temp files, personal config, credential files, etc.), do not commit or delete them yourself; use `request_user_input` to let the user choose: **add to `.gitignore`** or **commit directly**; continue the commit flow after handling it per the user's choice.
- When the repo contains changes clearly unrelated to this task, report the conflict in the result first and do not commit them yourself.
- After committing, perform no branch operations; the current branch stays unchanged.
- Before committing, always check that no keys, accounts, local private paths or temp files are being committed.

# Detailed Commit Format

```text
<type-prefix>: <commit-description>

## Change Goal

[Why this change was made, what problem it solves]

## Before

[State, problem, gap or limitation before the change]

## After

[State, capability or behavior change after the change]

## Key Changes

- `[file path]`
  - Reason for change: [why it changed]
  - Change content: [detailed description of what specifically changed; must include the key function/interface/doc item; describe the behavior change, do not copy code]
  - Change impact: [which behaviors, rules, modules, interfaces or docs are affected]

## Verification Result

- [command or manual check]: [result]

## Follow-ups

- [Risks or tasks still needing follow-up]
```

# Commit Rules

- Every git commit must contain both:
  1. Short description: the first line, preferably in "verb + object + purpose" form.
  2. Detailed description: the commit body, covering the change goal, files involved, reason for change, before/after differences, key function/interface/doc items, verification result and follow-on impact, consistent with the actual changes.
- Never write "verification passed" for content that was not verified.
- The detailed git commit description is explanatory summary only; do not copy code diffs or paste large source blocks.
- A git commit must not include an AI co-author line (such as `Co-Authored-By: Claude ...`); the commit must not contain any AI attribution.
- The commit description (short and detailed) must not expose platform-internal config directories or project memory directory maintenance details.
- To review a historical code version, prefer reading that commit's detailed description.
