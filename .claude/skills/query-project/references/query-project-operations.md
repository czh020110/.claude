# Query project operations

This reference contains operational details for `query-project-agent`.

## Scope

The script reads project fact documents from `introduction/` and writes only reusable cache files under `.claude/.cache/query-project/`.

Supported source files:

- `.md`
- `.markdown`
- `.txt`
- `.pdf`
- `.docx`

## Required gitignore entries

Before status sync, index refresh, or query, the script checks that project root `.gitignore` contains:

```gitignore
.claude/settings.local.json
.claude/.cache/
```

If missing, it returns `GITIGNORE_ERROR`. Add the missing entries before rerunning.

## Environment variables

The script automatically loads `.claude/settings.local.json` and merges its `env` values into `os.environ` before resolving configuration. Agents and callers do not need to inject those values manually.

Recommended full setup:

- `RAG_EMBEDDING_BASE_URL`
- `RAG_EMBEDDING_API_KEY`
- `RAG_EMBEDDING_MODEL`
- `RAG_RERANK_BASE_URL`
- `RAG_RERANK_API_KEY`
- `RAG_RERANK_MODEL`

DashScope defaults:

- Embedding URL: `https://dashscope.aliyuncs.com/compatible-mode/v1`
- Embedding model: `text-embedding-v4`
- Rerank URL: `https://dashscope.aliyuncs.com/compatible-api/v1`
- Rerank model: `qwen3-rerank`

## Commands

Query:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py \
  --query "user question or model-generated project detail question"
```

Sync config status:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py \
  --sync-config-status
```

Refresh index:

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py \
  --refresh-index
```

Useful query parameters:

```bash
--top-k 8
--candidate-k 40
--format markdown|json
--max-snippet-chars 800
--show-content
--chunk-max-chars 1800
--chunk-overlap-chars 200
--embedding-batch-size 10
--exclude-todo
--exclude "introduction/修改记录/**/*.md"
--no-rerank
```

## Windows output encoding check

If direct terminal output is garbled, capture stdout bytes into a UTF-8 file and read that file.

Use the query text as the cache filename:

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

Then read the printed `.md` file.

## Output requirements for subagent

`query-project-agent` should not forward raw full output unless necessary. It should return:

- question
- conclusion
- relevant path and line range
- relevant excerpt or concise paraphrase
- score when available
- follow-up if retrieval is insufficient
