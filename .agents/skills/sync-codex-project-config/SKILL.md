---
name: sync-codex-project-config
description: 从 GitHub 仓库同步 `AGENTS.md`、`.codex/`、`.agents/skills/`、`.project-memory/` 和 `.project-script/` 全套基础配置到当前项目，并自动把这些路径写入 `.gitignore`。当用户要求同步配置，或你发现项目缺少基础 Codex 配置时使用。
---

# sync-codex-project-config

当用户要求同步 Codex 项目配置，或你发现项目缺少 `AGENTS.md`、`.codex/`、`.agents/skills/` 等基础配置时，执行同步。

## 执行
直接执行脚本，非必须不要查看脚本代码。
```bash
bash .agents/skills/sync-codex-project-config/scripts/sync.sh
```

## 执行后向用户汇报

若脚本正常执行成功，不要做多余步骤，不要执行其他无关命令。只允许执行上述脚本，并根据脚本输出汇报：

1. 是否有基础配置文件变更（新增/覆盖/跳过）
2. 变更的文件列表摘要
3. 下游项目 `.gitignore` 是否有更新
4. 如果有错误，说明错误原因

## 同步策略

| 对象 | 行为 |
| --- | --- |
| `AGENTS.md` | 只替换规则区，保留本地「自定义提示词说明」及其以下内容 |
| `.codex/`、`.agents/skills/` | 直接覆盖；`.codex/agents/*.toml` 保留本地 `model` 字段 |
| `.project-memory/`、`.project-script/` | 只在目标文件或子目录不存在时新增模板，绝不覆盖已有记忆正文、索引和脚本 |
| `.gitignore` | 补齐 `.codex/`、`.agents/`、`.project-memory/`、`.project-script/`、`AGENTS.md` |
