---
name: sync-project-config
description: 用户要求同步项目基础配置，或发现配置缺失时使用；按客户端平台从 Codex 源生成对应 Agent、Skill 和项目模板。
---

# sync-project-config

这是所有项目 Agent 配置迁移的统一入口。不要单独维护 `.claude/`、`.zcode/` 或 `.codebuddy/` 中的 Skill/Agent 提示词。

## 唯一源

- Agent 源：`.codex/agents/*.toml`，其中 `developer_instructions` 是唯一提示词正文。
- Skill 源：`.agents/skills/<skill>/SKILL.md` 及其 `scripts/`、`references/` 等资源。
- 目标平台目录由脚本生成；生成时完整保留源 Agent/Skill 正文，只适配 YAML frontmatter、文件名、工具权限和平台目录等配置数据。

## 平台参数

根据当前客户端判断参数并传给脚本：

运行当前 `sync-project-config` Skill 目录下的 `scripts/sync.sh <平台>`。

`workbuddy` 是 `codebuddy` 的别名；模型统一传 `codebuddy`。

生成范围：

- `codex`：同步 Codex 源目录本身。
- `zcode`：从 Codex Agent 源生成 `.zcode/agents/`，Skill 使用共享 `.agents/skills/` 源。
- `claude`：从 Codex 源生成 `.claude/agents/` 和 `.claude/skills/`，并按规则生成 `CLAUDE.md`。
- `codebuddy`：从 Codex 源生成 `.codebuddy/agents/` 和 `.codebuddy/skills/`，只复制 CodeBuddy 可用资源；`workbuddy` 使用同一分支。

所有平台都只新增缺失的 `.project-memory/` 和 `.project-script/` 模板，不覆盖目标项目已有内容。CodeBuddy 的 `.mcp.json` 仅在目标缺失时新增。

## 边界

- 不修改根 `AGENTS.md` 的正文；Claude/ZCode 的工具名适配只发生在生成目标文件中。
- 不把生成目录当作源，不从 `.claude/`、`.zcode/` 或 `.codebuddy/` 反向同步。
- 不复制凭证、本地缓存、`settings.local.json`、`CODEBUDDY.local.md` 或 Codex UI 专用 `agents/openai.yaml` 到其他平台。
- 用户未明确要求同步时不调用；脚本成功后只汇报同步范围、文件变化和验证结果。
