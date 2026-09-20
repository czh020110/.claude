# CodeBuddy 适配层

- 根目录 `AGENTS.md` 继续作为项目主提示词，不创建重复的 `CODEBUDDY.md`。
- `.codebuddy/agents/` 提供 CodeBuddy 可读取的 Markdown 子代理定义，当前覆盖代码审查、项目记忆全量同步和外部文档查询；其职责边界与 `.codex/agents/` 保持一致。
- `.codebuddy/skills/` 提供项目级 Skill 入口。入口保留 CodeBuddy 所需的 `name`/`description` frontmatter，并携带 CodeBuddy 运行所需的脚本与参考资料，避免同步时依赖未复制的 `.agents/` 目录。
- CodeBuddy 适配层不复制 `.codex/agents/openai.yaml`、`.codex/config.toml` 或平台缓存；项目记忆仍由 `.project-memory/` 负责，MCP 只有在单独配置时才迁移。
- `sync-codex-project-config` 支持 `codebuddy`、`workbuddy` 别名；该分支只同步 `AGENTS.md`、`.codebuddy/`、缺失的 `.mcp.json`、`.project-memory/` 和 `.project-script/`，不复制其他平台目录。
