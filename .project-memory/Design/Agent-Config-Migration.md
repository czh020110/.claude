# 多平台 Agent 配置迁移

- `.codex/agents/*.toml` 是唯一 Agent 源，`.agents/skills/` 是唯一 Skill 源；源文件中的提示词正文只维护一份。
- `sync-project-config` 根据客户端参数生成 `.zcode/agents/`、`.claude/agents/`、`.claude/skills/`、`.codebuddy/agents/` 和 `.codebuddy/skills/`，只适配头部元数据、文件名、工具权限和平台目录，正文保持源文件内容。
- 目标平台目录是同步产物，不作为仓库内的长期提示词源；项目根 `AGENTS.md` 仍是统一主提示词。
- 项目记忆与验证模板由所有平台共享；CodeBuddy 仅在目标缺失时新增 `.mcp.json`，不覆盖本地配置。

