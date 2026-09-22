---
name: sync-project-memory
description: When the user asks to push, pull or check project memory sync status, handles `.project-memory/` through a standalone remote git repo.
---

# sync-project-memory

Syncs `.project-memory/` to a remote project memory repository as a standalone git repository. The branch is uniquely determined by the main code repo's `origin` remote URL: the same code repo always maps to the same `docs/<origin-url-slug>` branch in the remote memory repo.

## Project Identity

- The unique identity is the URL returned by `git remote get-url origin` in the main code repo.
- The script converts that URL into a stable `docs/<slug>` branch name; do not use a directory name or `.agents/project-id` anymore.
- When the main code repo has no `origin` configured, the script errors out instead of falling back to a local name.

## Usage

The entry script is `scripts/sync-memory.sh` under the current `sync-project-memory` Skill directory, with the argument `pull`, `push` or `info`.

## Handling by Output

The script outputs in English; match the keywords in the table below when reporting to the user:

| Output keyword | What to do |
|---|---|
| `push complete` / `pull complete` / `checked out remote branch` / `merged local content` | Tell the user it succeeded and briefly describe the change |
| `has no changes, nothing to push` | Tell the user there are no changes |
| `[SYNC_ERROR] Argument validation failed` | Relay the correct usage; if it shows `URL configured: no`, configure the URL first |
| `Uncommitted local changes` / `Ahead of remote: N` | Tell the user push is available |
| `Behind remote: N` | Tell the user pull is available |
| `Remote memory repository URL is not configured` | See "Configure URL" below |
| `git user identity is not configured` | Ask the user to run `git config --global user.name/email` first |
| `push failed, the remote has newer commits` | Ask the user to pull first, then push |
| `hit a merge conflict` / `hit a content conflict while merging` | Guide manual resolution (see "Conflict Handling") |
| `Remote memory repository is not reachable` | Check the URL, whether the GitHub repo exists, and the SSH key / token |

> If `.project-memory/` already has files but is not yet a git repo (for example it was just populated with templates by `sync-project-config`), the script brings it under version control and merges automatically; no manual action is needed.

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
