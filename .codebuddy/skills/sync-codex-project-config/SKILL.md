---
name: sync-codex-project-config
description: 用户要求同步项目基础配置时，使用 codebuddy 参数同步 CodeBuddy/WorkBuddy 可用的 AGENTS.md、.codebuddy/ 和 .project-* 模板。
---

# CodeBuddy 项目配置同步

仅在用户明确要求同步项目基础配置时执行：

```bash
bash .codebuddy/skills/sync-codex-project-config/scripts/sync.sh codebuddy
```

`workbuddy` 也可作为同义参数传给脚本，但模型统一使用 `codebuddy`。如需指定模板仓库，使用 `CODEBUDDY_CONFIG_REPO_URL`。

CodeBuddy/WorkBuddy 分支只同步：

- 根目录 `AGENTS.md`；保持原文，不创建重复的 `CODEBUDDY.md`。
- `.codebuddy/` 项目 Agent、Skill 和必要资源；跳过本地 settings、缓存和私有文件。
- 根目录 `.mcp.json`（若模板提供且目标缺失）；已有本地 MCP 配置不会覆盖。
- `.project-memory/` 与 `.project-script/`；只新增目标中不存在的模板，不覆盖本地事实记忆、索引和验证脚本。

不得复制 `.codex/`、`.zcode/`、`.claude/`、`.agents/` 或 Codex 专用 `agents/openai.yaml`。脚本会将 CodeBuddy 全局同步目标设为 `~/.codebuddy/skills/`，可用 `CODEBUDDY_GLOBAL_SKILL_DIR` 覆盖。
