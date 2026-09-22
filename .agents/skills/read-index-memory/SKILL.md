---
name: read-index-memory
description: Read the `.project-memory/` topic indexes and route to the relevant bodies.
---

# Purpose

`.project-memory/` uses an "index + chunked body" layout. This skill reads only each topic's `MEMORY.md`, so the model gets routing information first and then reads relevant bodies on demand; calling this skill must not turn into scanning every body.

This script reads only the **index content** (the `MEMORY.md` in each topic directory), not the body files.

# Execution

Use the Python script to read the indexes so it runs cross-platform (Windows/macOS/Linux):

Run `scripts/read_index_memory.py` under the current `read-index-memory` Skill directory.

The script never modifies, creates or deletes any file; it only outputs index content. Do not read its source; just use its output.

# Output and Next Actions

The script outputs the full content of each topic's `MEMORY.md` (path + content). Based on the index's coverage, key objects and read conditions, combined with the current task, decide which body files to read next; read no bodies when no topic matches.
