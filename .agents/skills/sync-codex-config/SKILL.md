---
name: sync-codex-config
description: 从 GitHub 仓库同步 `.codex/`、`.project-memory/` 和 `.project-script/` 基础配置文件到当前项目。使用智能合并策略并自动管理 `.gitignore`。当用户要求同步配置，或你发现项目缺少基础 Codex 配置时使用。
---

# sync-codex-config

当用户要求同步 Codex 项目配置，或你发现项目缺少 `AGENTS.md`、`.codex/`、`.agents/skills/` 等基础配置时，执行同步。

## 执行

```bash
bash .agents/skills/sync-codex-config/scripts/sync.sh
```

## 执行后向用户汇报

根据脚本输出汇报结果：

1. 是否有基础配置文件变更（新增/覆盖/跳过）
2. 变更的文件列表摘要
3. 下游项目 `.gitignore` 是否有更新
4. 如果有错误，说明错误原因
