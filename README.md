# Morrowmark: Vibe Coding - Project Persistence and Memory Management

<p align="center">
  <img src="assets/morrowmark-logo.png" alt="Morrowmark project icon" width="520">
</p>

**Project memory and coding-agent workflows for Codex, ZCode, Claude Code, CodeBuddy, WorkBuddy, and OpenCode.**

<p align="center">
  <a href="README_CN.md">简体中文</a> | <strong>English</strong>
</p>

<p align="center">
  <a href="https://github.com/czh020110/Morrowmark"><img alt="platforms" src="https://img.shields.io/badge/platforms-Codex%20%7C%20ZCode%20%7C%20Claude%20Code%20%7C%20CodeBuddy%20%7C%20WorkBuddy%20%7C%20OpenCode-blue"></a>
</p>

**A codebase that remembers—and an agent that can pick up the thread.**

Morrowmark gives each repository durable, project-local context. It records confirmed current facts separately from settled future designs, and guides agents to load relevant topics as work changes. Shared skills and subagents make planning, documentation research, verification, and memory updates reusable across six coding clients. Memory stays in the project repository, not the client's global memory.

## What It Remembers

- **Project facts:** purpose and scope (`Target`), current implementation (`Design`), boundaries and project-specific preferences (`Boundary`, `Preferences`).
- **Working knowledge:** commands, environment, project documents, reusable tools, and recurring lessons (`Commands`, `Environment`, `Documents`, `Tools`, `Pitfalls`).
- **Future design:** settled plans, including work not yet implemented (`Plan/`). `TODO/TODO.md` remains the user's backlog.

## Task Workflow

1. Read the topic indexes and TODO, then only the relevant memory bodies.
2. As durable project preferences or boundaries become clear, record them; repeated, consistent signals may be recorded as inferred.
3. Do the requested project work and run `post-verify` for every modification before delivery.
4. After `post-verify`, make one final memory pass for implementation facts, conflicts with existing memory, and execution lessons with confirmed recurrence risk and reuse value. Exclude unverified claims and temporary progress.

## Quick Start

1. Install this repository's `sync-morrowmark/` directory into the current client's global skill directory:

   | Client | Global skill directory |
   | --- | --- |
   | Codex, ZCode, OpenCode | `~/.agents/skills/` |
   | Claude Code | `~/.claude/skills/` |
   | CodeBuddy | `~/.codebuddy/skills/` |
   | WorkBuddy international | `~/.workbuddy-ai/skills/` |
   | WorkBuddy domestic | `~/.workbuddy/skills/` |

   Or install this Skill with Vercel's Skills CLI:

   ```bash
   npx skills add https://github.com/czh020110/Morrowmark/tree/main/sync-morrowmark --global
   ```

   Select the current client if prompted. To update a CLI-managed installation later, run `npx skills update sync-morrowmark`. This installs the global Skill; initialize or update a project separately in step 2. See the [Skills CLI documentation](https://github.com/vercel-labs/skills) for supported agents and options.

   Replace any earlier global installation with this renamed skill before the next sync.

   Or copy this prompt to your agent:

   ```text
   Install the `sync-morrowmark` skill from https://github.com/czh020110/Morrowmark/tree/main/sync-morrowmark into the global skills directory for the current client. The linked repository is only the skill source; the target is the repository open in this session. If this is the first installation, read `references/PROJECT_USAGE.md` from the installed skill and briefly explain how to use Morrowmark. An update of an existing installation is not a first install. Then ask whether I want to initialize or update the current repository; do not run a sync until I confirm.
   ```

2. For the first sync, run the global copy you installed. It creates a project-local copy. For later updates, run this from the target repository root:

   ```bash
   bash sync-morrowmark/scripts/sync.sh codex
   ```

   Replace `codex` with `zcode`, `claude`, `codebuddy`, `workbuddy`, `workbuddy-cn`, or `opencode` as appropriate.

The sync generates the platform's agent and skill configuration and adds project memory templates. It preserves existing custom prompts, accumulated memory bodies, and same-named agents' reasoning settings where the platform supports them.

## Project Memory

Memory lives in `.project-memory/` and uses an index-and-body layout. Each topic's `MEMORY.md` routes agents to separate topic bodies; put durable facts in the relevant body.

| Directory | Purpose |
| --- | --- |
| `Target/` | Project purpose, scope, and acceptance criteria. |
| `Design/` | Current implementation, architecture, and design rationale. |
| `Plan/` | Settled future designs; mark items complete only after implementation and verification. |
| `Boundary/` | Behaviors to preserve, exclusions, constraints, and quality requirements. |
| `Preferences/` | Project-specific working and communication preferences. |
| `Commands/` | Install, run, build, test, deploy, and recovery commands. |
| `Environment/` | Tool versions, platform limits, paths, and external services. |
| `Documents/` | Index of user-maintained project documents; referenced document bodies are read-only. |
| `Tools/` | Reusable helpers for scripts, visualizations, and data conversion. |
| `Pitfalls/` | Recurring issues, how to recognize them, and how to avoid them. |
| `TODO/` | `TODO/TODO.md` is the user's backlog; agents edit it only when explicitly asked. |

**Maintaining memory:** Read all topic indexes and TODO first, then only the bodies relevant to the task. Record confirmed, reusable project facts in the matching topic. Keep `Plan/` for settled designs; `TODO/TODO.md` is user-maintained.

## Verification Scripts (`.project-script/`)

Store reusable verification scripts in type-specific subdirectories and list each script's path, purpose, applicable scenarios, entry command, and prerequisites in `.project-script/MEMORY.md`. One-off checks do not need a saved script. Run `post-verify` after each project modification. This repository currently has no reusable verification scripts registered.

## Team Memory Collaboration

`sync-project-memory` shares `.project-memory/` through a dedicated remote Git repository. The script derives a `docs/<slug>` branch from the code repository's `origin` URL; clones using the same `origin` use the same memory branch. Keep `origin` identical across clones—changing the code repository URL changes the derived branch. Configure the same memory repository URL on each device with the skill's `config <URL>` operation.

With no direction, the skill checks local and remote state, recommends `pull`, `push`, or pull-then-push, and asks before making changes. Specify `pull`, `push`, or `info` to run that operation directly. Pull merges remote updates into local memory; push publishes local updates. Conflicts stop for manual resolution; the script never discards local or remote content or force-pushes.

## Skills

### User-invoked

| Skill | Use it to |
| --- | --- |
| `sync-morrowmark` | Install or update project agents, skills, and templates. |
| `draft-long-term-plan` | Create or extend the project's intended design in `Plan/`. |
| `collect-update-memory` | Reconcile project memory with a range of commits and local changes. |
| `sync-project-memory` | Push or pull project memory through a separate remote repository. |
| `git-commit` | Create purpose-grouped commits when requested. |
| `handoff` | Prepare a concise, copyable prompt for continuing work in a new session. |

### Used by the agent as needed

| Skill | Role |
| --- | --- |
| `read-index-memory` | Read memory indexes and route to relevant bodies at task start. |
| `design-alignment` | Settle a design change or conflict with the user and record the agreed design. |
| `docs-research` | Look up multiple or complex external documentation questions. |
| `post-verify` | Run final checks after a change. |
| `update-memory` | Record confirmed facts after verification. |

## Subagents

- `collect_update_memory` — audits memory topic structure and performs full memory syncs.
- `docs_research` — looks up external technical documentation without inspecting local project code.
