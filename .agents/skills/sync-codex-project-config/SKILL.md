---
name: sync-codex-project-config
description: 从 GitHub 仓库同步项目基础配置到当前项目。先判断当前平台是 Codex 还是 ZCode：Codex 同步 `AGENTS.md`、`.agents/`、`.codex/`、`.project-memory/`、`.project-script/`；ZCode 同步 `AGENTS.md`、`.agents/`、`.zcode/`、`.project-memory/`、`.project-script/`。自动把这些路径写入 `.gitignore`。当用户要求同步配置，或你发现项目缺少基础配置时使用。
---

# sync-codex-project-config

当用户要求同步项目配置，或你发现项目缺少基础配置时，执行同步。

## 平台判断（MUST）

执行前先判断当前运行平台：

- **Codex**：同步 `AGENTS.md`、`.agents/`、`.codex/`、`.project-memory/`、`.project-script/`。
- **ZCode**：同步 `AGENTS.md`、`.agents/`、`.zcode/`、`.project-memory/`、`.project-script/`，即把 `.codex/` 替换为 `.zcode/`。

`.project-memory/` 和 `.project-script/` 是平台无关共享目录，两种平台都同步，不做区分。

## 全局自同步（MUST）

运行本 skill 时，脚本会把本 skill 自身同步/覆盖到各 agent 的全局 skill 目录，保证 Codex、ZCode、Claude Code 三个 agent 在任何未配置模板的目录里都能直接调用全局 `sync-codex-project-config` 来同步项目：

- **首选目录 `~/.agents/skills/sync-codex-project-config/`**（可用 `CODEX_GLOBAL_SKILL_DIR` 覆盖）：Codex 与 ZCode 都按 `.agents` 约定读取该目录，作为跨 agent 的全局 skill 主位置，总是写入。
- **`~/.zcode/skills/`**：在 ZCode 中优先级高于 `~/.agents/skills`，已存在同名副本时会一并刷新，避免旧副本遮蔽更新结果；不存在时不创建。
- **`~/.claude/skills/`**：Claude Code 不读 `~/.agents/skills`，只认该目录；检测到 `~/.claude`（用户装有 Claude Code）时确保最新副本；未安装时不创建。

只覆盖这一个同名 skill，不触碰其他全局 skill。版本来源优先级：当前项目有本 skill 时用项目版本（可能含本地未提交修改），否则用模板仓库版本。覆盖方式为整目录先删后拷，旧版本残留文件会被清理，从全局副本运行脚本时自身也不会被原地截断。

## 执行
直接执行脚本，非必须不要查看脚本代码。
```bash
bash .agents/skills/sync-codex-project-config/scripts/sync.sh codex
```

ZCode 平台传 `zcode`：
```bash
bash .agents/skills/sync-codex-project-config/scripts/sync.sh zcode
```

脚本会先执行上述全局自同步，再按所选平台继续项目配置同步；向用户汇报时包含全局 skill 的更新情况。

## 执行后向用户汇报

若脚本正常执行成功，不要做多余步骤，不要执行其他无关命令。只允许执行上述脚本，并根据脚本输出汇报：

1. 是否有基础配置文件变更（新增/覆盖/跳过）
2. 变更的文件列表摘要
3. 下游项目 `.gitignore` 是否有更新
4. 如果有错误，说明错误原因

## 同步策略

| 对象 | 行为 |
| --- | --- |
| `AGENTS.md` | 只替换规则区，保留本地「自定义提示词说明」及其以下内容；ZCode 平台额外把规则区中的 `update_plan` 替换为 `TodoWrite`、`request_user_input` 替换为 `AskUserQuestion`（自定义提示词区不替换） |
| `.zcode/config.json` | 本地已存在时只追加本地缺失的 `mcp.servers` 条目（如 context7），不覆盖本地已有 server 和其他配置；本地不存在时整文件新增 |
| `.codex/`、`.agents/skills/` | 直接覆盖；`.codex/agents/*.toml` 保留本地 `model` 字段 |
| `.project-memory/`、`.project-script/` | 只在目标文件或子目录不存在时新增模板，绝不覆盖已有记忆正文、索引和脚本 |
| `.gitignore` | 补齐 `.codex/`、`.agents/`、`.project-memory/`、`.project-script/`、`AGENTS.md` |
