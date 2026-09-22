---
name: docs-research
description: When three or more external libraries/interfaces need to be verified at once, or a single technical question involves complex version/migration details, delegate to the docs_research agent to check official sources.
---

# docs-research

Entry point for batched external technical documentation lookups. The main model calls the `docs_research` agent to do the lookup; this skill only organizes the questions, invokes, and assembles the results.

## Trigger Scenarios (MUST)

- Three or more technical docs/interfaces/libraries/frameworks/SDKs need to be looked up.
- A single interface lookup that involves multiple versions, migration, authentication or build details — a complex scenario where a direct lookup is inefficient.
- Usage of multiple external dependencies in the current task needs to be confirmed at the same time.

Do not use this skill for fewer than three interfaces; the main model queries directly with `context7` or web search tools.

## Invocation (MUST)

1. **Split the questions into several independent ones**: each library/interface/scenario to look up becomes one `### Question N: ...`. Questions must be independently answerable:
   - `What client initialization parameters does GLM-5.3's Anthropic Messages interface have`
   - `The MCP configuration format for context7 in Codex config.toml`
   - `Whether a certain interface is deprecated in the current version, and the recommended replacement`
2. **Call the `docs_research` agent**: through the platform's corresponding subagent invocation mechanism, passing the `### Question N: <specific question>` list in the prompt.
3. **Assemble the results after the agent returns**: every question needs `Conclusion / Evidence / Suggested usage / Risks and uncertainties`; if a question has no conclusion, tell the user it is unconfirmed and do not guess to fill it in.

## Pure Documentation Lookup Assistant (MUST)

`docs_research` is a pure documentation lookup assistant and **does not need to and should not inspect local project code, files, configuration or repo structure**. When invoking it, pass only the technical questions themselves; do not attach local code snippets, file paths, diffs or project context; it returns external technical material based only on `context7` and web search tools.

## Question Template

```md
### Question 1: What is the officially recommended usage of <library/interface A>?

### Question 2: Is the old interface of <library/interface B> deprecated in the current version? What replaces it?

### Question 3: What is the configuration/invocation format of <library/interface C> on <platform>?
```

## Boundaries

- Look up only external technical material; do not look up internal project docs in `.project-memory/`.
- After receiving results, if more detail is needed, the main model can use `context7` / search tools itself against the sources the agent provided.
