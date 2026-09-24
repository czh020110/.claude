# persistent coding memory

**Multi-platform, project-level coding memory.**

[简体中文](README_CN.md) | **English**

[![platforms](https://img.shields.io/badge/platforms-Codex%20%7C%20ZCode%20%7C%20Claude%20Code%20%7C%20CodeBuddy%20%7C%20WorkBuddy%20%7C%20OpenCode-blue)](https://github.com/czh020110/.claude)

This is a template repository, not a runnable software project. It installs a set of agents, skills and a project memory system into any development repo with one command.

**Project-level memory, not global memory.** Everything it accumulates stays inside the repository it was installed into — it never writes to the client's global memory — and it is meant for code projects only.

Memory is organized by topic, in nine of them:

| Topic | What it records |
| --- | --- |
| `Commands` | Install, run, build, test, evaluate, deploy and recover workflows |
| `Environment` | Tools/versions, hardware, paths, env vars, external services, platform limits |
| `Documents` | User-maintained project docs (bodies are read-only by default) |
| `Target` | Currently effective project purpose, scope and acceptance criteria |
| `Design` | The design of the code as it exists now: architecture, module responsibilities, collaboration model, rationale |
| `Boundary` | Behavior that must be preserved, out-of-scope items, limits, quality floor, and what must not be done — including what the user said not to do |
| `Preferences` | Project-scoped preferences for how the agent works here: writing and reply style, comment and naming conventions — never global preferences |
| `Tools` | Reusable helper scripts, visualizations, statistics or data conversion tools |
| `Pitfalls` | Reusable lessons: applicable scenarios, detection signals, root cause, avoidance |

Alongside those nine fact topics, `.project-memory/Plan/` holds the designs and plans the project has settled on — the design it is meant to have, including the parts that are not built yet. It is not a fact topic: `Plan` is the design, `Design` is what the code actually does, and each design unit is marked `[ ]` / `[-]` / `[x]`.

One source is maintained here, and the `sync-project-config` global skill generates and distributes it to six platforms: **Codex / ZCode / Claude Code / CodeBuddy / WorkBuddy / OpenCode**.

---

## Install it as a global skill and use it

`sync-project-config/` at the repo root is the global skill install source, and the only copy of it in the repo. It is not a project-level skill and it is not one of the skills under `.agents/skills/`.

### Step 1: Install `sync-project-config` into the global skill directory

Either copy the repo-root `sync-project-config/` directory into your client's global skill directory:

| Client | Global skill directory |
| --- | --- |
| Codex / ZCode | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| CodeBuddy (domestic build) | `~/.codebuddy/skills/` |
| WorkBuddy international (`workbuddy`) | `~/.workbuddy-ai/skills/` |
| WorkBuddy domestic (`workbuddy-cn`) | `~/.workbuddy/skills/` |
| OpenCode | `~/.agents/skills/` |

Or copy the sentence below and send it to your agent, letting it install and initialize everything for you:

```text
Install sync-project-config from the current project root into the global skill directory of the current client, then use it to initialize the current project.
```

### Step 2: Run the sync inside your development repo

Go to the root of the development repo you want to initialize or update, then run the platform that matches your client:

```bash
bash sync-project-config/scripts/sync.sh codex
bash sync-project-config/scripts/sync.sh zcode
bash sync-project-config/scripts/sync.sh claude
bash sync-project-config/scripts/sync.sh codebuddy
bash sync-project-config/scripts/sync.sh workbuddy
bash sync-project-config/scripts/sync.sh workbuddy-cn
bash sync-project-config/scripts/sync.sh opencode
```

`codebuddy`, `workbuddy` and `workbuddy-cn` are different targets and write to different directories. Quick check: `~/.codebuddy/` means `codebuddy`, `~/.workbuddy-ai/` means `workbuddy`, `~/.workbuddy/` means `workbuddy-cn`. Picking the wrong one fails silently rather than erroring.

The **first** run in a repo uses the global copy instead, because the project-local `sync-project-config/` does not exist yet — that run fetches the latest template and drops the project copy in place:

```bash
bash ~/.agents/skills/sync-project-config/scripts/sync.sh codex   # or your client's global skill directory
```

After that, the project copy is the entry point, and the sync adds `sync-project-config/` to `.gitignore` along with the other generated paths.

Before using the global skill in a repo, it asks once for authorization if you have not already authorized it there — if you say no, it does not run the script. A normal successful sync needs no follow-up review: an existing `AGENTS.md` (or `CLAUDE.md` on Claude) without the `<!-- sync-project-config:custom-prompts -->` marker is preserved in full after the template prompts and marker. The skill does not inspect custom prompts or ask to migrate them after syncing; migrate project facts into `.project-memory/` only when you explicitly request that as a separate task. If a sync cannot safely preserve existing content, the agent stops and asks about that specific conflict.

### Step 3: Confirm the result

When it finishes, the target repo should contain the platform's `agents/` and `skills/` directories, `AGENTS.md` (plus `CLAUDE.md` on Claude), and the `.project-memory/` and `.project-script/` templates.

---

## `.project-memory/`: the memory

`.project-memory/` holds the project memory. Each topic has a `MEMORY.md` that is an index only, plus body files that hold the facts, so the agent reads the indexes first and only the bodies it needs.

```
.project-memory/
├── Plan/MEMORY.md          ← the expected design, index only
├── Plan/<topic>.md         ← one complete design per topic
├── Commands/MEMORY.md      ← index only
├── Commands/<topic>.md     ← the facts
├── Environment/  Documents/  Target/  Design/
├── Boundary/  Preferences/  Tools/  Pitfalls/
└── TODO/TODO.md
```

`Plan/` holds the designs and plans the project has settled on — the design it is meant to have, including the parts that are not built yet. It uses the same index-and-body layout as the topics, and each design unit carries a status marker on its heading: `[ ]` not implemented, `[-]` in progress, `[x]` implemented and verified. Entries stay after they are built, so `Plan/` holds the full design while `Design/` holds what the code actually does. `draft-long-term-plan` writes it with you; `design-alignment` records a design change in it.

`TODO/TODO.md` is the one file the agent leaves to you: your own backlog, written to only when you ask.

Memory never stores credentials. A sync adds missing template files and refreshes the **title line** of each one — everything below the title is what you have accumulated and is never overwritten.

## `.project-script/`: reusable verification scripts

`.project-script/` holds the scripts used to verify changes, grouped by type, with `.project-script/MEMORY.md` indexing them (path, purpose, entry command, prerequisites). Scripts read credentials only from environment variables and never store keys or tokens.

---

## How a task runs

`AGENTS.md` drives every task through one loop:

1. **Read the memory indexes** — `read-index-memory` reads every topic's `MEMORY.md` (including `Plan/`) plus `TODO/TODO.md`.
2. **Read only the bodies the index points to** — the index decides what is relevant; nothing else is scanned.
3. **Make the change.**
4. **Verify before delivery** — `post-verify` runs the final targeted checks and leaves evidence.
5. **Write down what the task confirmed** — once verification passes, `update-memory` records the facts the task established.

**Memory records facts about the current project; `.project-memory/Plan/` records the design it is meant to have.** A design the user has agreed to goes into `Plan/`, including the parts that are not built yet, and your own backlog goes into `.project-memory/TODO/TODO.md`. The agent reads both at the start of every task, so an idea parked there is not lost.

---

## Skills

| Skill | What it does | Invoked by |
| --- | --- | --- |
| `read-index-memory` | Reads the topic indexes and routes to the relevant bodies | agent |
| `update-memory` | Writes the facts this round confirmed into the matching topic | agent |
| `post-verify` | Final verification gate before delivery | agent |
| `design-alignment` | Settles a design change or conflict with the user through multi-round options, then records the agreed design in `Plan/` | agent |
| `draft-long-term-plan` | Designs the project with the user from zero to its final form and writes it into `Plan/` | user |
| `docs-research` | Batched external documentation lookup, delegated to the `docs_research` agent | agent |
| `git-commit` | Creates a git commit: groups by purpose, writes the structured message, verifies | user |
| `collect-update-memory` | Orchestrates a full memory sync, delegated to the `collect_update_memory` agent | user |
| `sync-project-memory` | Pushes and pulls `.project-memory/` through a standalone remote repo, so memory survives across devices | user |
| `sync-project-config` | The distribution entry: installs and updates a project's agents, skills and templates | user |

## Agents

| Agent | What it does |
| --- | --- |
| `collect_update_memory` | Full memory sync: consolidates current facts, in commit / incremental / local-change order |
| `docs_research` | Pure external documentation lookup; never reads local code |

---

## Maintaining this template

### Editing prompts

**Edit only the source, never the generated directories.** After changing `.codex/agents/*.toml` or `.agents/skills/*/SKILL.md`, commit and push to the template repo; the next `sync.sh` run in each development repo pulls the latest version automatically.

### Editing `AGENTS.md`

Everything **above** the `<!-- sync-project-config:custom-prompts -->` marker is managed and replaced on every sync; everything **below** it is each project's own area and is preserved. Put common rules above the marker.
