---
name: sync-project-memory
description: When the user asks to sync, push, pull or check project memory through a standalone remote Git repository. For directionless sync requests, inspect status, recommend an operation and ask the user before changing anything.
---

# sync-project-memory

Syncs `.project-memory/` to a remote project memory repository as a standalone git repository. The branch is uniquely determined by the main code repo's `origin` remote URL: the same code repo always maps to the same `docs/<origin-url-slug>` branch in the remote memory repo.

## Project Identity

- The unique identity is the URL returned by `git remote get-url origin` in the main code repo.
- The script converts that URL into a stable `docs/<slug>` branch name; do not use a directory name or `.agents/project-id` anymore.
- When the main code repo has no `origin` configured, the script errors out instead of falling back to a local name.

## Usage

The entry script is `scripts/sync-memory.sh` under the current `sync-project-memory` Skill directory. It accepts `pull`, `push`, `info`, `status`, `diagnose` or `config <url>`.

When the user explicitly requests an operation such as `pull`, `push` or `info`, run that operation directly. If it fails or reveals a conflict or other problem, stop and explain the issue before taking another action.

## Directionless Sync Requests

When the user says only "sync" or invokes this Skill without a direction:

1. Run `bash scripts/sync-memory.sh info` and inspect fetched ahead/behind counts, repository initialization state, and uncommitted changes. Do not infer direction from timestamps or filenames.
2. If the main repository has no `origin` or the memory repository URL is not configured, ask the user to configure the missing value; do not guess it.
3. If there are no local changes and the local and remote branches are aligned, report that memory is already in sync.
4. Otherwise, summarize the observed state, recommend the appropriate operation, and ask the user to choose. Offer only applicable choices such as `pull`, `push`, `pull then push`, or `skip`; for diverged branches, distinguish pull-only from pull-and-push. Do not run `pull` or `push` until the user chooses.
   - Remote is ahead only: recommend `pull`.
   - Local is ahead, or only local uncommitted changes exist: recommend `push`.
   - Both local and remote have commits: recommend `pull` to merge, followed by `push` if the merge succeeds; offer pull-only as an alternative.
   - Local memory is uninitialized or no upstream branch is known: explain that `pull` can initialize/check the remote, while `push` can publish existing local content; ask which direction the user wants.
   - Local uncommitted changes and remote commits are both present: explain that pull may be blocked by overlapping changes; ask whether to attempt the merge or handle local changes first.
5. If the chosen pull or merge conflicts, stop and guide the user through resolution. Never discard local or remote content or force-push.
6. If a chosen push is rejected because the remote changed after `info`, explain that pull-and-merge is needed and ask before proceeding with it.

## Handling by Output

The script outputs in English; match the keywords in the table below when reporting to the user:

| Output keyword | What to do |
|---|---|
| `push complete` / `pull complete` / `checked out remote branch` / `merged local content` | Tell the user it succeeded and briefly describe the change |
| `has no changes, nothing to push` | Tell the user there are no changes |
| `[SYNC_ERROR] Argument validation failed` | Relay the correct usage; if it shows `URL configured: no`, configure the URL first |
| `Uncommitted local changes` / `Ahead of remote: N` | For directionless sync, use these facts to recommend push; ask before running it |
| `Behind remote: N` | For directionless sync, recommend pull; ask before running it |
| `Remote memory repository URL is not configured` | See "Configure URL" below |
| `git user identity is not configured` | Ask the user to run `git config --global user.name/email` first |
| `push failed, the remote has newer commits` | Explain that pull-and-merge is needed; ask before running pull |
| `hit a merge conflict` / `hit a content conflict while merging` | Guide manual resolution (see "Conflict Handling") |
| `Remote memory repository is not reachable` | Check the URL, whether the GitHub repo exists, and the SSH key / token |

> If `.project-memory/` already has files but is not yet a git repo (for example it was just populated with templates by `sync-morrowmark`), the script brings it under version control and merges automatically; no manual action is needed.

## Configure URL

When the output is `Remote memory repository URL is not configured`, ask the user for a GitHub/GitLab empty repository URL (dedicated to project memory, not the main project repo):

The configuration entry is `scripts/sync-memory.sh config <URL>` under the current `sync-project-memory` Skill directory.

After configuring, run pull or push again.

## Conflict Handling

On conflict the script aborts and leaves `<<<<<<<` / `=======` / `>>>>>>>` markers in the files. Guide the user:

Enter `.project-memory/`, resolve the conflict and commit, then run `scripts/sync-memory.sh push` under the current `sync-project-memory` Skill directory.

To abandon the merge: `cd .project-memory && git merge --abort`

## Other Commands

Use `scripts/sync-memory.sh config <URL>` under the current `sync-project-memory` Skill directory to configure the URL; use the same script's `status` argument to view detailed status.

Across devices: the Skill comes along with the current platform config; the project identity comes from the main repo's origin remote, so switching devices needs no extra configuration. The remote project memory repo URL must be reconfigured on each device.
