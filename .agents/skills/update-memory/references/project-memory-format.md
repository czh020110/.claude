# Project Memory Format and Maintenance Spec

This file is on-demand reference shared by `update-memory` and `collect_update_memory`. Read it only when writing to or restructuring `.project-memory/`; it is not a must-read prompt for every task. Plans and decisions that are not settled yet, and design decisions that are not implemented yet, are recorded uniformly in `.project-memory/TODO/Pending.md` and are not facts managed by this file.

## Directory and Fact Ownership

Project memory consists of eight topics: `Commands`, `Environment`, `Documents`, `Target`, `Design`, `Boundary`, `Tools`, `Pitfalls`. Each topic directory contains an index-only `MEMORY.md` plus sub-topic body files, each scoped to one topic; do not create catch-all bodies like "other/misc/basic operations".

- `Commands`: install, run, build, test, evaluate, deploy and failure-recovery workflows.
- `Environment`: tools/versions, hardware, paths, environment variables, external services and platform limits.
- `Documents`: user-maintained project docs; bodies are read-only by default, indexes are maintained by the full memory agent.
- `Target`: currently effective project purpose, scope and acceptance criteria — intent, not implementation (that is `Design`); stage plans and options that are not settled yet go into TODO/STEP/Pending.
- `Design`: the architecture, module responsibilities, collaboration model and design rationale of the code as it exists now; design decisions that are not implemented yet go into TODO/Pending.
- `Boundary`: behavior that must be preserved, explicitly excluded scope, limits and quality floor.
- `Tools`: reusable helper scripts, visualizations, statistics or data conversion tools.
- `Pitfalls`: reusable execution lessons confirmed during execution that may recur, with applicable scenarios, detection signals, root cause and avoidance steps; do not record one-off tool errors, transient failures, raw logs or details that cannot be transferred.

Each fact keeps a single authoritative home and other topics reference it by link. New facts go into the matching topic, are not appended to `Target` by time, and never include unsettled plans, still-open decisions, design decisions that are not implemented, modification requests the user has not approved, tutorials, candidate options or change history. Execution-lesson bodies hold only reusable lessons and do not replace normative facts in other topics.

## Index Rules

`MEMORY.md` may contain only index lines. If a body exists it must have an index, and an index must not point at a missing file. Index descriptions must state coverage, key objects and the task scenarios in which the file should be read, and must avoid restating volatile implementation details.

```md
# Index Paths and Summaries Related to <Topic>

- [document name](document-name.md) - coverage, key objects, and the task scenarios in which this document should be read.
```

Structural changes (create, delete, rename, move, split, merge) must land in the same change as the index and be verified; if only the content changed and responsibilities did not, the index does not need updating. At the end, check that indexes and bodies are one-to-one, with no broken links, orphans or outdated duplicates.

## Pending vs. Fact Split

- `TODO/Pending.md` uses the same checkbox format as `TODO.md` and records specifically plans and decisions that are not settled yet, design decisions that are settled but not implemented yet, and project plan changes requested by the user.
- `TODO/TODO.md` is the user-maintained ordinary todo list; the main model may modify it only when the user explicitly asks to write or update it, and must not add todos on its own while working.
- When such content first appears in a discussion, the main model writes it into Pending immediately; a Pending entry must contain background, the decision pending confirmation, completion criteria and related scope.
- A Pending entry is removed once it is no longer pending, and the final fact is then written into the matching body: a decision that needs no code change is written as soon as the user settles it, while a design decision is written only once it is implemented and verified. If a plan is rejected or cancelled, only the Pending entry is removed and nothing is written into facts.
- `update-memory` and `collect-update-memory` do not create, modify or clean up Pending, and must not treat Pending content as a source of facts.

## Pitfalls Write Boundary (Reusable Execution Lessons)

- Write into the matching `Pitfalls` sub-topic only when a problem is confirmed during execution to carry recurrence risk and can be abstracted into applicable scenarios, detection signals, root cause or avoidance actions.
- One-off command failures, transient network/environment failures, debugging details with no reproduction value, and pure change history are not written; state them in the current task result instead.
- Each lesson sub-topic records only experiential conclusions and their reuse conditions; if it also touches current design or constraints, write those separately into the matching fact topics and cross-link them, and never write candidate options as execution lessons.

## Write Decisions

1. First read the target topic's `MEMORY.md`, then read only the relevant bodies per the index; do not scan unrelated topics.
2. Prefer updating an existing body for the same object/workflow; create a new topic only when there is genuinely an independent read scenario, a complete workflow, or a different code path.
3. When judging whether to split, look at semantic boundaries first: different read conditions, entry/output/verification methods, independent evolution, or a merged file that is clearly too long (about 250–300 lines or more) can be split; short documents that are always read and modified together should be merged.
4. Bodies record only current facts, each stating its basis: code, configuration, diffs or verification results for implemented facts, the user's explicit statement for declared ones. Never write passwords, tokens, private keys, cookies or other directly usable credentials; record only variable names and secure configuration methods.
5. Do not change the language that existing memory documents are written in (English, Chinese, etc.).

When comparing two candidate topics, check at least: whether the main problem, core objects, inputs/outputs, execution stage/state, results/verification, and the code changes that trigger them are the same. Highly identical (5–6 items) must be merged; moderately identical (3–4 items) defaults to merging and split only when conditions such as different read scenarios/entry/output/verification, independent evolution, or a clearly over-long merged file hold at the same time; low similarity (0–2 items) may become a separate topic. Split bodies must be self-contained and cannot leave only a "common main flow + diff patch".

Bodies must follow the fact ownership, indexing and topic boundaries defined in this file; when existing memory format or topic ownership is found non-compliant, fix it per this spec and update the index.

## Initialization and Update

- Initialization: while the core planning files are still empty templates, create the topic bodies and indexes needed from the current code, configuration, scripts and commands; do not create empty files.
- When the project has no source code at all and only has project memory templates, initialize only `Boundary` and `Target` where facts genuinely exist; once code exists, initialize topics such as `Environment` and `Commands` from the actual content, and initialize `Tools` only if reusable scripts exist.
- Update: when memory already exists, replace outdated facts based on the current code, configuration, commit diffs and verification results; do not guess from file names, old documents or conversation alone.
- `TODO/STEP.md`, `TODO/TODO.md` and `TODO/Pending.md` are not maintained by this spec's real-time memory update flow; among them TODO.md may be written by the main model only after explicit user authorization, and Pending.md is recorded directly by the main model; `.project-script/` is likewise not part of project memory bodies or indexes.
