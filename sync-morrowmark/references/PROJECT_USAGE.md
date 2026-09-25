# Morrowmark Project Usage Guide

This guide explains Morrowmark, how to install and sync it, and which Skills and Agents the repository provides. Read it only after a first-time installation of `sync-morrowmark` or when the user asks how to use the project. Do not read it during routine project syncs.

## 1. What Is Morrowmark?

Morrowmark is a configuration template for coding agents. It brings reusable Skills, Agents, project prompts, and project-memory workflows into target repositories. It supports Codex, ZCode, Claude Code, CodeBuddy, WorkBuddy, and OpenCode.

`sync-morrowmark` is the user-level entry Skill. Installing it does not initialize the current project. Install or update project configuration by running the sync script from the target repository root.

## 2. Install the Skill and Initialize a Project

### Install the global entry Skill

Install it from GitHub with Vercel's Skills CLI:

```bash
npx skills add https://github.com/czh020110/Morrowmark/tree/main/sync-morrowmark --global
```

You can also install it manually in the client's global Skill directory listed in the repository README. If Vercel's Skills CLI manages the installed copy, update it with `npx skills update sync-morrowmark`.

Installing the Skill for the first time is separate from initializing a project. After confirming a first-time installation, the Agent may briefly explain this guide and ask whether the user wants to initialize the current project. Do not sync a project without the user's request.

### Initialize or update a target repository

Run this command from the target repository root:

```bash
bash sync-morrowmark/scripts/sync.sh codex
```

Replace `codex` with the target client:

| Argument | Client |
| --- | --- |
| `codex` | Codex |
| `zcode` | ZCode |
| `claude` | Claude Code |
| `codebuddy` | CodeBuddy |
| `workbuddy` | WorkBuddy international edition |
| `workbuddy-cn` | WorkBuddy domestic edition |
| `opencode` | OpenCode |

The script fetches the current version from the configured template remote, replaces the target repository's `sync-morrowmark/` copy, and generates the client-specific configuration. Re-running it is a project update or sync, not a first-time Skill installation. Update a CLI-managed global Skill copy separately with `npx skills update sync-morrowmark`.

## 3. What the Sync Changes

- The source files are in `.codex/agents/` and `.agents/skills/`. Do not edit generated client directories directly; edit the template sources and sync again.
- Codex uses the source directories. Other clients receive their own generated Agent and Skill directories. WorkBuddy project-level configuration is written to `.codebuddy/`.
- Sync adds missing project-memory and verification-script templates and refreshes memory-file titles. It preserves existing memory bodies.
- `AGENTS.md` and Claude Code's `CLAUDE.md` preserve user-authored prompts. When a file has the `sync-morrowmark:custom-prompts` marker, content at and below the marker is kept. If an existing file has no marker, its content is adopted below the marker.
- Project configuration directories are added to `.gitignore`. To share project memory across clones, use `sync-project-memory` instead of committing generated directories.

## 4. Project-Memory Directories

`.project-memory/` uses an index-and-body layout. Read the topic indexes first, then only the bodies relevant to the task. Store confirmed, reusable project facts in the matching topic.

| Directory | Purpose |
| --- | --- |
| `Target/` | Project purpose, scope, and acceptance criteria. |
| `Design/` | Current implementation, architecture, and design rationale. |
| `Plan/` | Settled future designs; mark an item complete only after implementation and verification. |
| `Boundary/` | Behaviors to preserve, exclusions, and constraints. |
| `Preferences/` | Project-specific working and communication preferences. |
| `Commands/` | Install, run, build, test, deploy, and recovery commands. |
| `Environment/` | Tool versions, paths, external services, and platform limits. |
| `Documents/` | Index of user-maintained project documents; referenced document bodies are read-only. |
| `Tools/` | Reusable scripts, visualizations, and data-conversion tools. |
| `Pitfalls/` | Reusable lessons, detection signals, and ways to avoid recurring issues. |
| `TODO/` | `TODO/TODO.md` is the user's backlog. Agents edit it only when explicitly asked. |

`.project-script/` holds reusable verification scripts. Its index is `.project-script/MEMORY.md`. Run `post-verify` after project modifications.

## 5. Skills in This Repository

### Skills users can request

| Skill | Purpose |
| --- | --- |
| `sync-morrowmark` | Install or update project Agents, Skills, and templates. |
| `draft-long-term-plan` | Create or extend settled project designs when the user explicitly asks. |
| `collect-update-memory` | Reconcile project memory with a range of commits or local changes when the user asks. |
| `sync-project-memory` | Check, pull, or push project memory through a separate remote repository. |
| `git-commit` | Group, verify, and commit changes when the user asks for a commit. |
| `handoff` | Prepare a continuation prompt for another session. |

### Skills used by the Agent as needed

| Skill | Purpose |
| --- | --- |
| `read-index-memory` | Read memory indexes at task start and locate relevant bodies. |
| `design-alignment` | Settle new designs or conflicts with existing designs with the user. |
| `docs-research` | Research multiple or complex external technical-documentation questions. |
| `post-verify` | Run final checks after modifications. |
| `update-memory` | Record eligible, confirmed current facts. |

Users can request a Skill by name. The Agent may also invoke a Skill when its purpose matches the task. `TODO/TODO.md`, user-maintained documents, and unsettled designs each have their own boundaries; memory sync does not mean rewriting all project materials.

## 6. Agents in This Repository

These subagents are delegated work by the main Agent and normally do not need to be named by the user:

| Agent | Purpose |
| --- | --- |
| `collect_update_memory` | When the user requests a full or staged memory sync, audit memory structure and sync eligible implemented facts while protecting designs in `Plan/`. |
| `docs_research` | Look up external technical documentation and return sourced findings without inspecting local project code. |

## 7. Common Workflows

- **Initialize or update project configuration:** Run `sync-morrowmark/scripts/sync.sh <client-argument>` from the target repository root.
- **Finish a code change:** Follow the project's workflow, then run `post-verify` after modifications.
- **Plan an unimplemented design:** Use `draft-long-term-plan` when the user explicitly asks. Use `design-alignment` to settle a new design or a conflict with an existing one. `Plan/` stores only agreed designs.
- **Share project memory with a team:** First configure the separate memory repository with `sync-project-memory config <memory-repository-url>` and use the same URL across clones. Then use `info` to check status, `pull` to fetch, or `push` to publish. With no direction, the Skill checks status and recommends an action before asking to make changes. Conflicts stop for manual resolution.
- **Commit changes:** Commit only when the user explicitly asks, using `git-commit`.

## 8. Questions That Need More Detail

This guide is an introduction, not a substitute for the implementation. If the user asks about a specific rule, file-replacement behavior, or client difference, inspect the latest configured Morrowmark template source. Read the relevant `AGENTS.md`, `.codex/agents/*.toml`, `.agents/skills/<skill>/SKILL.md`, Skill resources, or scripts under `sync-morrowmark/scripts/`. Use the current source as the authority. If the remote is unavailable, say so and inspect the available local copy.
