# Project Memory Format and Maintenance Spec

This file is on-demand reference shared by `update-memory`, `collect_update_memory` and `draft-long-term-plan`. Read it only when writing to or restructuring `.project-memory/`; it is not a must-read prompt for every task. The design the project is meant to have, including the parts that are not built yet, lives in `.project-memory/Plan/`; it is not a fact topic and is not managed as one by this file.

## Directory and Fact Ownership

Project memory consists of nine topics: `Commands`, `Environment`, `Documents`, `Target`, `Design`, `Boundary`, `Preferences`, `Tools`, `Pitfalls`. Each topic directory contains an index-only `MEMORY.md` plus sub-topic body files, each scoped to one topic; do not create catch-all bodies like "other/misc/basic operations". `Plan/` is not one of these topics: it follows the same index-and-body layout but holds the expected design rather than facts, and is specified under "Plan vs. Fact Split" below.

- `Commands`: install, run, build, test, evaluate, deploy and failure-recovery workflows.
- `Environment`: tools/versions, hardware, paths, environment variables, external services and platform limits.
- `Documents`: index of user-owned, non-code project documents and materials stored anywhere in the repository; source bodies remain user-owned and read-only. `collect-update-memory` maintains this index; the ordinary `update-memory` skill does not maintain this topic.
- `Target`: currently effective project purpose, scope and acceptance criteria — intent, not implementation (that is `Design`); the design the project is meant to have, including what is not built yet, is `Plan`.
- `Design`: the architecture, module responsibilities, collaboration model and design rationale of the code as it exists now; the expected design, including design decisions that are not implemented yet, is `Plan`.
- `Boundary`: behavior that must be preserved, explicitly excluded scope, limits and quality floor, plus everything the project must not do — what the user has said not to do, designs the user has explicitly rejected, and what the agent has confirmed during execution must not be done.
- `Preferences`: project-scoped preferences for how the agent works in this repository — writing and reply style, comment and naming conventions, commit-message habits and similar. Only preferences specific to this project or its code belong here; a preference that would hold in every project is not a project fact and belongs in the user-level memory instead.
- `Tools`: reusable helper scripts, visualizations, statistics or data conversion tools.
- `Pitfalls`: reusable execution lessons confirmed during execution that may recur, with applicable scenarios, detection signals, root cause and avoidance steps; do not record one-off tool errors, transient failures, raw logs or details that cannot be transferred.

Each fact keeps a single authoritative home and other topics reference it by link. New facts go into the matching topic, are not appended to `Target` by time, and never include unsettled plans, still-open decisions, design decisions that are not implemented, modification requests the user has not approved, tutorials, candidate options or change history. Execution-lesson bodies hold only reusable lessons and do not replace normative facts in other topics.

## Evidence for Memory Entries

- User-stated project purpose, scope, boundaries and preferences may be recorded from the explicit statement or approval; no technical verification is required. Keep these project-scoped. Cross-project preferences belong in user-level memory.
- A project-scoped preference or boundary that the user did not state directly may be recorded as **inferred** when the same signal appears consistently across separate task contexts, with no contrary correction. Record that it is inferred and its brief conversational basis; do not infer it from a single task-specific request, silence or an unresolved option.
- Implementation facts require evidence from the current code, configuration, diffs or verification. For a modification, wait for `post-verify` before recording them.
- An intended design belongs in `Plan/` only after the user agrees to it; it may be recorded before implementation. Reusable execution lessons require a confirmed recurrence basis.
- Never store temporary task progress, unverified implementation claims or speculation. If evidence is unclear, omit the entry or ask only when the ambiguity blocks a decision.

## Index Rules

`MEMORY.md` may contain only index lines. If a body exists it must have an index, and an index must not point at a missing file. Index descriptions must state coverage, key objects and the task scenarios in which the file should be read, and must avoid restating volatile implementation details.

```md
# Index Paths and Summaries Related to <Topic>

- [document name](document-name.md) - coverage, key objects, and the task scenarios in which this document should be read.
```

Structural changes (create, delete, rename, move, split, merge) must land in the same change as the index and be verified; if only the content changed and responsibilities did not, the index does not need updating. At the end, check that indexes and bodies are one-to-one, with no broken links, orphans or outdated duplicates.

## Sub-topic Naming Granularity

A topic directory names a broad ownership area; each child body must name a strictly narrower, independently retrievable subject within it. Do not name a child with the parent topic's name, a same-granularity synonym, or a broad catch-all label. For example, `Target/Project goals`, `Design/Project design` and `Commands/Project commands` merely repeat their parent topics' broad scopes; these are invalid child names. Prefer a name that identifies the actual narrower scope, such as `Target/supported-repositories-and-acceptance.md` or `Design/sync-orchestration-and-agent-boundaries.md`, only when that scope is truly covered by the body.

Do not invent narrower scope just to satisfy naming. If a body covers the parent topic as a whole, organize its facts into genuine subtopics only when the split criteria support them; otherwise report that no valid narrower division is evident instead of creating a redundant child. File names and index labels, plus headings used only as structural titles, may be narrowed to reflect the body's actual scope. Do not rewrite fact statements or settled design content to make a title fit; report a conflict when a compliant name would require changing that content.

## Plan vs. Fact Split

- `.project-memory/Plan/` holds the designs and plans the project has settled on — the design it is meant to have, including the parts that are not built yet. It uses the same layout as the fact topics: `Plan/MEMORY.md` is an index only, each body is one complete design topic, and the index and topic-similarity rules above apply to it unchanged.
- Only a design the user has agreed to is written there. A candidate option, an unapproved request and a still-open decision are not recorded: the discussion is settled first, then the design is written.
- Every design unit carries a status marker on its heading: `[ ]` not implemented, `[-]` in progress, `[x]` implemented and verified. The marker changes as the work lands, and an entry is never deleted for being implemented.
- `Plan/` is not a source of facts. Once a design is implemented and verified, the fact it produced is written into the matching fact topic with `update-memory` — `Design` for the code's design — and the `Plan/` entry stays where it is. A design that is rejected or cancelled has its entry removed and writes no fact.
- `TODO/TODO.md` is the user-maintained ordinary todo list; the main model may modify it only when the user explicitly asks to write or update it, and must not add todos on its own while working.
- `update-memory` does not create, modify or clean up `Plan/`. `collect-update-memory` may repair `Plan/`'s format and topic boundaries — split, merge, rename, re-index — but must never change, reword or delete the designs and plans recorded there. Neither may treat `Plan/` content as a source of facts.

## Pitfalls Write Boundary (Reusable Execution Lessons)

- Write into the matching `Pitfalls` sub-topic only when a problem is confirmed during execution to carry recurrence risk and can be abstracted into applicable scenarios, detection signals, root cause or avoidance actions.
- One-off command failures, transient network/environment failures, debugging details with no reproduction value, and pure change history are not written; state them in the current task result instead.
- Each lesson sub-topic records only experiential conclusions and their reuse conditions; if it also touches current design or constraints, write those separately into the matching fact topics and cross-link them, and never write candidate options as execution lessons.

## Write Decisions

1. First read the target topic's `MEMORY.md`, then read only the relevant bodies per the index; do not scan unrelated topics.
2. Prefer updating an existing body for the same object/workflow; create a new topic only when there is genuinely an independent read scenario, a complete workflow, or a different code path. Follow "Sub-topic Naming Granularity" when naming each child body.
3. When judging whether to split, look at semantic boundaries first: different read conditions, entry/output/verification methods, independent evolution, or a merged file that is clearly too long (about 250–300 lines or more) can be split; short documents that are always read and modified together should be merged.
4. Bodies record only current facts, each stating its basis: code, configuration, diffs or verification results for implemented facts, the user's explicit statement for declared ones. Never write passwords, tokens, private keys, cookies or other directly usable credentials; record only variable names and secure configuration methods.
5. Do not change the language that existing memory documents are written in (English, Chinese, etc.).

When comparing two candidate topics, check at least: whether the main problem, core objects, inputs/outputs, execution stage/state, results/verification, and the code changes that trigger them are the same. Highly identical (5–6 items) must be merged; moderately identical (3–4 items) defaults to merging and split only when conditions such as different read scenarios/entry/output/verification, independent evolution, or a clearly over-long merged file hold at the same time; low similarity (0–2 items) may become a separate topic. Split bodies must be self-contained and cannot leave only a "common main flow + diff patch".

Bodies must follow the fact ownership, indexing and topic boundaries defined in this file; when existing memory format or topic ownership is found non-compliant, fix it per this spec and update the index.

## Initialization and Update

- Initialization: while `Boundary` and `Target` are still empty templates, create the topic bodies and indexes needed from the current code, configuration, scripts and commands; do not create empty files.
- When the project has no source code at all and only has project memory templates, initialize only `Boundary` and `Target` where facts genuinely exist; once code exists, initialize topics such as `Environment` and `Commands` from the actual content, and initialize `Tools` only if reusable scripts exist.
- `Plan/` is never initialized from code: it starts empty and is filled by `draft-long-term-plan` when the user asks for it.
- Update: when memory already exists, replace outdated facts based on the current code, configuration, commit diffs and verification results; do not guess from file names, old documents or conversation alone.
- `TODO/TODO.md` and `.project-memory/Plan/` are not maintained by this spec's real-time memory update flow: TODO.md may be written by the main model only after explicit user authorization, and `Plan/` is written by the main model, `draft-long-term-plan` and `design-alignment`; `.project-script/` is likewise not part of project memory bodies or indexes.
