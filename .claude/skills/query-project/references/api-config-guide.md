# Main-model-only RAG config guide

This document is for the main model only.

Do not treat this file as a subagent execution reference.
Subagents should only return `CONFIG_ERROR[...]` summaries and stop.
The main model is responsible for user-facing configuration guidance.

## When the main model should use this guide

Only use this guide when `query-project` or `query_introduction_rag.py` returns:

- `CONFIG_ERROR[embedding]`
- `CONFIG_ERROR[rerank]`

Do not use this guide for normal retrieval flow.
Do not use this guide for `GITIGNORE_ERROR`.

## Main model responsibilities

When receiving `CONFIG_ERROR[...]`, the main model should:

1. Explain that the failure is caused by missing or invalid RAG configuration.
2. Use Claude Code options to ask the user how to proceed.
3. If the user wants help, guide them to provide the required values.
4. After configuration is fixed, re-run `query-project`.

## Claude Code option flow

Offer exactly these options:

1. `I will configure environment variables myself`
2. `Please configure environment variables for me`
3. `Do not use RAG retrieval`

## Required configuration items

The full setup includes 6 items:

1. `RAG_EMBEDDING_BASE_URL`
2. `RAG_EMBEDDING_API_KEY`
3. `RAG_EMBEDDING_MODEL`
4. `RAG_RERANK_BASE_URL`
5. `RAG_RERANK_API_KEY`
6. `RAG_RERANK_MODEL`

Optional fallback variables:

- `OPENAI_BASE_URL`
- `RAG_API_KEY`
- `OPENAI_API_KEY`
- `DASHSCOPE_API_KEY`

## What the main model should do for each option

### 1. I will configure environment variables myself

Provide:

- the 6 variable names
- what each variable means
- a copy-paste example
- how to re-run status sync after setup

### 2. Please configure environment variables for me

Ask the user for:

- embedding base URL
- embedding API key
- embedding model ID
- rerank base URL
- rerank API key
- rerank model ID

### 3. Do not use RAG retrieval

Tell the user:

- `query-project` can remain in `(rag未配置)` state
- `update-docs` should skip vector refresh while RAG is unconfigured
- non-RAG workflows can continue

## Example configuration

### DashScope example

```bash
export RAG_EMBEDDING_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
export RAG_EMBEDDING_API_KEY="your-embedding-key"
export RAG_EMBEDDING_MODEL="text-embedding-v4"
export RAG_RERANK_BASE_URL="https://dashscope.aliyuncs.com/compatible-api/v1"
export RAG_RERANK_API_KEY="your-rerank-key"
export RAG_RERANK_MODEL="qwen3-rerank"
```

## After configuration is fixed

The main model should re-run:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py --sync-config-status
```

If status becomes `(rag已配置)`, the main model may continue with:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py --refresh-index
```
