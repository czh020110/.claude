---
name: sync-codex-project-config
description: 用户要求同步项目基础配置，或明确发现配置缺失时使用；按当前 Codex/ZCode/Claude/CodeBuddy 平台同步可用模板并保留本地记忆边界。
---

# sync-codex-project-config

当用户要求同步项目配置，或你发现项目缺少基础配置时，执行同步。

## 平台判断（MUST）

执行前先判断当前运行平台：

- **Codex**：同步 `AGENTS.md`、`.agents/`、`.codex/`、`.project-memory/`、`.project-script/`。
- **ZCode**：同步 `AGENTS.md`、`.agents/`、`.zcode/`、`.project-memory/`、`.project-script/`，即把 `.codex/` 替换为 `.zcode/`，并对 `AGENTS.md` 规则区做 ZCode 工具名适配。
- **Claude Code**：同步 `AGENTS.md`（作为源）、`.claude/`、`.project-memory/`、`.project-script/`；由 `AGENTS.md` 派生项目根目录 `CLAUDE.md`（只面向 Claude Code agent，不跨 agent 平台）。
- **CodeBuddy / WorkBuddy**：同步 `AGENTS.md`、`.codebuddy/`、`.project-memory/`、`.project-script/`；不复制 `.codex/`、`.zcode/`、`.claude/` 或 `.agents/`，CodeBuddy 适配文件必须自包含。
  - 若模板仓库提供根目录 `.mcp.json`，仅在目标缺失时新增，不覆盖本地 MCP/认证配置。

`.project-memory/` 和 `.project-script/` 是平台无关共享目录，各平台都同步，不做区分。

## 全局自同步（MUST）

运行本 skill 时，脚本会把本 skill 自身覆盖到**当前平台 agent** 的全局 skill 目录（不跨 agent 平台），保证在未配置模板的目录里也能直接调用全局 `sync-codex-project-config` 来同步项目：

- **Codex**：写 `~/.agents/skills/sync-codex-project-config/`（可用 `CODEX_GLOBAL_SKILL_DIR` 覆盖）。
- **ZCode**：写 `~/.agents/skills/sync-codex-project-config/`；`~/.zcode/skills/` 已有同名副本时一并刷新（它在 ZCode 中优先级更高，旧副本会遮蔽更新），不存在时不创建。
- **Claude Code**：写 `~/.claude/skills/sync-codex-project-config/`（注意是 skills，带 s）；Claude Code 不读 `~/.agents` 约定目录。
- **CodeBuddy / WorkBuddy**：写 `~/.codebuddy/skills/sync-codex-project-config/`；使用 `CODEBUDDY_GLOBAL_SKILL_DIR` 可覆盖默认目录。

CodeBuddy/WorkBuddy 可用 `CODEBUDDY_CONFIG_REPO_URL` 指定配置模板仓库；未设置时回退到 `CODEX_CONFIG_REPO_URL` 和默认模板仓库。

只覆盖这一个同名 skill，不触碰其他全局 skill。版本来源优先级：当前项目有本 skill 时用项目版本（可能含本地未提交修改；claude 平台优先取 `.claude/skills/` 副本），否则用模板仓库版本。覆盖方式为整目录先删后拷，旧版本残留文件会被清理，从全局副本运行脚本时自身也不会被原地截断。

## 执行
直接执行脚本，非必须不要查看脚本代码。按当前运行平台选择参数：
```bash
bash .agents/skills/sync-codex-project-config/scripts/sync.sh codex    # Codex
bash .agents/skills/sync-codex-project-config/scripts/sync.sh zcode    # ZCode
bash .claude/skills/sync-codex-project-config/scripts/sync.sh claude   # Claude Code
bash .agents/skills/sync-codex-project-config/scripts/sync.sh codebuddy # CodeBuddy / WorkBuddy
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
| `CLAUDE.md`（仅 claude 平台） | 由 `AGENTS.md` 派生到项目根目录：规则区替换 `update_plan`→`TaskCreate`、`request_user_input`→`AskUserQuestion`，自定义提示词区优先保留本地根 `CLAUDE.md` 的内容。不读取、不删除项目内旧版 `.claude/CLAUDE.md`（避免误删用户文件），如存在需用户自行处理 |
| `.zcode/config.json` | 本地已存在时只追加本地缺失的 `mcp.servers` 条目（如 context7），不覆盖本地已有 server 和其他配置；本地不存在时整文件新增 |
| `.codex/`、`.claude/`、`.agents/skills/` | 直接覆盖；`.codex/agents/*.toml` 保留本地 `model` 字段 |
| `.codebuddy/`（CodeBuddy） | 只复制 CodeBuddy 可读取的项目 Agent、Skill 和必要资源；跳过 `settings.local.json`、`CODEBUDDY.local.md`、`.cache/` 等本地文件 |
| `.mcp.json`（CodeBuddy） | 模板存在且目标缺失时新增；目标已有时跳过，避免覆盖本地 MCP/认证配置 |
| `.project-memory/`、`.project-script/` | 只在目标文件或子目录不存在时新增模板，绝不覆盖已有记忆正文、索引和脚本 |
| `.gitignore` | CodeBuddy 只补齐 `.project-memory/`、`.project-script/` 和 `.codebuddy` 本地覆盖文件；其他平台保持原有条目 |
