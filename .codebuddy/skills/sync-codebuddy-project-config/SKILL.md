---
name: sync-codebuddy-project-config
description: 用户明确要求同步 WorkBuddy/CodeBuddy 项目配置时，维护 .codebuddy 的 Agent 与 Skill 适配层，保持 AGENTS.md 不变。
---

# CodeBuddy 项目配置同步

仅在用户明确要求同步 CodeBuddy 配置时执行：

1. 以当前 `.codebuddy/` 文件为同步入口，不依赖 `.agents/` 或 `.codex/` 目录。
2. 保持根目录 `AGENTS.md` 原样，不创建重复的 `CODEBUDDY.md`。
3. 不复制 Codex 的 `agents/openai.yaml`、`.codex/config.toml` 或平台专用缓存；MCP 仅在用户明确需要时单独迁移到项目 `.mcp.json`。
4. 修改后新建 WorkBuddy 会话，通过 `/skills` 和 `/agents` 检查加载结果，并运行项目验证。
5. 不自动更新项目事实记忆；适配方案完成并验证后由主模型按触发条件使用 `update-memory`。

