# Morrowmark

**Project memory and coding-agent workflows for Codex, ZCode, Claude Code, CodeBuddy, WorkBuddy, and OpenCode.**

[简体中文](README_CN.md) | **English**

[![platforms](https://img.shields.io/badge/platforms-Codex%20%7C%20ZCode%20%7C%20Claude%20Code%20%7C%20CodeBuddy%20%7C%20WorkBuddy%20%7C%20OpenCode-blue)](https://github.com/czh020110/.claude)

Morrowmark installs reusable agents, skills, and project memory into a development repository. Memory stays in that repository; it is not written to the client's global memory.

## Quick Start

1. Install this repository's `sync-morrowmark/` directory into the current client's global skill directory:

   | Client | Global skill directory |
   | --- | --- |
   | Codex, ZCode, OpenCode | `~/.agents/skills/` |
   | Claude Code | `~/.claude/skills/` |
   | CodeBuddy | `~/.codebuddy/skills/` |
   | WorkBuddy international | `~/.workbuddy-ai/skills/` |
   | WorkBuddy domestic | `~/.workbuddy/skills/` |

   Replace any earlier global installation with this renamed skill before the next sync.

   Or copy this prompt to your agent:

   ```text
   Install the `sync-morrowmark` skill from https://github.com/czh020110/.claude/tree/main/sync-morrowmark into the global skills directory for the current client. The linked repository is only the skill source; the target is the repository open in this session. After installation, ask whether I want to initialize or update that repository now. Do not run a sync until I confirm.
   ```

2. For the first sync, run the global copy you installed. It creates a project-local copy. For later updates, run this from the target repository root:

   ```bash
   bash sync-morrowmark/scripts/sync.sh codex
   ```

   Replace `codex` with `zcode`, `claude`, `codebuddy`, `workbuddy`, `workbuddy-cn`, or `opencode` as appropriate.

The sync generates the platform's agent and skill configuration and adds project memory templates. It preserves existing custom prompts, accumulated memory bodies, and same-named agents' reasoning settings where the platform supports them.

## Project Memory

Memory lives in `.project-memory/` and uses an index-and-body layout. The nine fact topics are `Commands`, `Environment`, `Documents`, `Target`, `Design`, `Boundary`, `Preferences`, `Tools`, and `Pitfalls`.

- Each topic's `MEMORY.md` is an index. Agents read the indexes first and then only the relevant topic bodies.
- `Design` records what the code does now. `Plan/` records settled intended designs, including work not yet implemented.
- `TODO/TODO.md` is the user's backlog; agents edit it only when asked.

For a normal task, the agent reads memory indexes, works on the task, verifies changes, then records only confirmed reusable facts. A full `collect-update-memory` run has two phases: restructure topics without changing facts, then sync facts from commits and local changes.

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
