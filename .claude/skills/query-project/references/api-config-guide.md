# RAG setup guide

Use this guide only when `query_introduction_rag.py` returns `CONFIG_ERROR[...]`.

## When to enter this guide

Only enter this guide when the script reports one of these configuration problems:

- Missing configuration
- Invalid configuration
- Permission/authentication failure
- Service endpoint unreachable

- If the script returns `GITIGNORE_ERROR`, add the missing entries to the project root `.gitignore` before rerunning the command. Required entries: `.claude/settings.local.json` and `.claude/.cache/`.

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

## Claude Code option flow

When the user needs help after a `CONFIG_ERROR[...]`, use Claude Code options and offer exactly these choices:

1. `I will configure environment variables myself`
2. `Please configure environment variables for me`
3. `Do not use RAG retrieval`

The user can switch options with the arrow keys.

## What to do for each option

### 1. I will configure environment variables myself

Give the user the variable names and the setup steps.

You should provide:

- all 6 variable names
- what each variable means
- a copy-paste example
- how to rerun status sync after setup

Example template:

```md
Please configure these environment variables:
- RAG_EMBEDDING_BASE_URL
- RAG_EMBEDDING_API_KEY
- RAG_EMBEDDING_MODEL
- RAG_RERANK_BASE_URL
- RAG_RERANK_API_KEY
- RAG_RERANK_MODEL

After configuration, run:
python .claude/skills/query-project/scripts/query_introduction_rag.py --sync-config-status
```

### 2. Please configure environment variables for me

Ask the user for the values needed to configure the environment.

You should ask for:

- embedding base URL
- embedding API key
- embedding model ID
- rerank base URL
- rerank API key
- rerank model ID

If embedding and rerank share the same provider or key, confirm whether the user wants to reuse the same value.

### 3. Do not use RAG retrieval

Acknowledge that the project will not use RAG retrieval for now.

You should:

- tell the user that `query-project` can remain in `(rag未配置)` state
- tell the user that `update-docs` will skip vector refresh while the skill stays unconfigured
- continue with non-RAG workflows

## Example configurations

### DashScope example

```bash
export RAG_EMBEDDING_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
export RAG_EMBEDDING_API_KEY="your-embedding-key"
export RAG_EMBEDDING_MODEL="text-embedding-v4"
export RAG_RERANK_BASE_URL="https://dashscope.aliyuncs.com/compatible-api/v1"
export RAG_RERANK_API_KEY="your-rerank-key"
export RAG_RERANK_MODEL="qwen3-rerank"
```

### Generic OpenAI-compatible providers

```bash
export RAG_EMBEDDING_BASE_URL="https://your-embedding-provider/v1"
export RAG_EMBEDDING_API_KEY="your-embedding-key"
export RAG_EMBEDDING_MODEL="your-embedding-model-id"
export RAG_RERANK_BASE_URL="https://your-rerank-provider/v1"
export RAG_RERANK_API_KEY="your-rerank-key"
export RAG_RERANK_MODEL="your-rerank-model-id"
```

## Windows output encoding check

If query output is garbled in a Windows terminal, write stdout bytes to a UTF-8 file and read the file instead of trusting terminal rendering.

Name the cache file from the query text: `.claude/.cache/query-project/<query>.md`. Replace unsafe filename characters with `-`; stderr uses the same filename with `.err`.

```bash
python - <<'PY'
import json, os, re, subprocess, sys
from pathlib import Path
query = '项目的 RAG 记忆与上下文系统是什么'
settings = json.loads(Path('.claude/settings.local.json').read_text(encoding='utf-8'))
env = os.environ.copy()
env.update(settings.get('env', {}))
env['PYTHONIOENCODING'] = 'utf-8'
cmd = [sys.executable, '.claude/skills/query-project/scripts/query_introduction_rag.py', '--query', query, '--top-k', '3']
proc = subprocess.run(cmd, env=env, capture_output=True)
safe_name = re.sub(r'[\\/:*?"<>|\s]+', '-', query).strip('-') or 'query'
out_path = Path('.claude/.cache/query-project') / f'{safe_name}.md'
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_bytes(proc.stdout)
if proc.stderr:
    out_path.with_suffix('.err').write_bytes(proc.stderr)
print(out_path.as_posix())
raise SystemExit(proc.returncode)
PY
```

Then read the printed `.md` file. If the file shows normal Chinese, the RAG result is valid and only the terminal rendering is broken.

## Final step after setup

After the user finishes configuration, run:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py --sync-config-status
```

If status becomes `(rag已配置)`, vector refresh can be triggered later with:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py --refresh-index
```
