---
name: sync-project-config
description: 用户要求同步项目基础配置，或发现配置缺失时使用；作为全局 Skill 从 Codex 源初始化和更新项目 Agent、Skill 及项目模板。
---

# sync-project-config

这是全局配置迁移入口，不是当前项目自动加载的项目级 Skill。将本目录安装到当前客户端的全局 Skill 目录后，使用它初始化或更新项目。

## 唯一源

- Agent 源：模板仓库 `.codex/agents/*.toml`，其中 `developer_instructions` 是唯一提示词正文。
- Skill 源：模板仓库 `.agents/skills/<skill>/SKILL.md` 及其 `scripts/`、`references/` 等资源。
- 目标平台目录由本 Skill 生成；生成时完整保留源 Agent/Skill 正文，只适配 YAML frontmatter、文件名、工具权限和平台目录等配置数据。

## 使用方式

1. 将当前目录 `sync-project-config/` 安装到客户端的全局 Skill 目录：
   - Codex/ZCode：`~/.agents/skills/sync-project-config/`
   - Claude Code：`~/.claude/skills/sync-project-config/`
   - CodeBuddy（国内版）：`~/.codebuddy/skills/sync-project-config/`
   - WorkBuddy：`~/.workbuddy-ai/skills/sync-project-config/`（国际版）或 `~/.workbuddy/skills/`（国内版）
   - OpenCode：`~/.agents/skills/sync-project-config/`（OpenCode 原生读该目录，无需软链）
2. 或直接提示 Agent：**“请把当前项目根目录的 sync-project-config 安装到当前客户端的全局 Skill 目录，然后用它初始化当前项目。”**
3. 判断客户端并传入平台参数：`codex`、`zcode`、`claude`、`codebuddy`、`workbuddy` 或 `opencode`。

**统一安装策略（唯一副本 + 软链）**：脚本始终把真实目录安装到规范位置 `~/.agents/skills/sync-project-config/`；不读 `~/.agents/skills` 的客户端，由脚本在其自己的 Skill 目录里建软链指回规范副本，避免多份拷贝漂移。已存在的软链会被替换；若目标位置是真实目录则跳过并提示，绝不删除。

`codebuddy` 与 `workbuddy` 是两个独立平台，不能混用：CodeBuddy 用 `~/.codebuddy/skills`，WorkBuddy 用 `~/.workbuddy-ai/skills`（国际版）与 `~/.workbuddy/skills`（国内版）。WorkBuddy 的 Code 模式只从全局目录加载 Skill，因此 `workbuddy` 平台不生成项目级 `agents/` 与 `skills/`。

脚本每次启动时会先从远程模板仓库获取最新的 `sync-project-config`，覆盖当前项目根目录的同名目录，然后重新执行更新后的脚本，再进行其余同步。这样全局旧版本也能先自更新再执行最新逻辑。

## 生成范围

- `codex`：同步 Codex 源目录本身。
- `zcode`：从 Codex Agent 源生成 `.zcode/agents/`，Skill 使用共享 `.agents/skills/` 源。
- `claude`：从 Codex 源生成 `.claude/agents/` 和 `.claude/skills/`，并按规则生成 `CLAUDE.md`。
- `codebuddy`：从 Codex 源生成 `.codebuddy/agents/` 和 `.codebuddy/skills/`，只复制 CodeBuddy 可用资源。
- `workbuddy`：只在全局装 Skill（规范副本 + 软链），**不生成项目级目录**；`.mcp.json` 仅在目标缺失时新增。
- `opencode`：从 Codex 源生成 `.opencode/agents/` 和 `.opencode/skills/`；全局 Skill 直接用规范目录（OpenCode 原生读 `~/.agents/skills/`），不建软链——OpenCode 要求各位置 skill 名唯一，重复会导致冲突。

所有平台只新增缺失的 `.project-memory/` 和 `.project-script/` 模板，不覆盖目标项目已有内容。CodeBuddy 与 WorkBuddy 的 `.mcp.json` 仅在目标缺失时新增。

## 边界

- 用源码替换根 `AGENTS.md` 分割线以上的受控区，保留分割线以下的项目自定义内容；Codex 保留 `update_plan` / `request_user_input`，Claude Code、ZCode、CodeBuddy、WorkBuddy 改写为 `TodoWrite` / `AskUserQuestion`，OpenCode 改写为 `todowrite` / `question`。
- 不把生成目录当作源，不从 `.claude/`、`.zcode/` 或 `.codebuddy/` 反向同步。
- 不复制凭证、本地缓存、`settings.local.json`、`CODEBUDDY.local.md` 或 Codex UI 专用 `agents/openai.yaml` 到其他平台。
- 用户未明确要求同步时不调用；脚本成功后只汇报同步范围、文件变化和验证结果。
