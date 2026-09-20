---
name: update-memory
description: 仅在确认已实施且可验证的项目事实、有效约束、偏好、环境、命令或可复用执行经验时更新项目记忆。
---

# CodeBuddy 项目级入口

仅在事实已经实施并有代码、配置或验证证据，或确认了可复用执行经验时使用：

- 只更新对应的 `.project-memory/<主题>/` 正文和索引。
- 不写未实施方案、Pending/TODO、单次错误、临时推测、凭证或修改日志。
- 主模型直接维护；不调用子代理、不创建 commit。
- 首次写入或结构变化前读取 `.codebuddy/skills/update-memory/references/project-memory-format.md`。
- `MEMORY.md` 只做索引，正文一一对应。

主题路由：`Commands` 记录命令，`Environment` 记录环境，`Target` 记录已生效目标，`Design` 记录当前设计，`Boundary` 记录限制，`Tools` 记录可复用工具，`Pitfalls` 记录可复用执行经验；`Documents` 正文默认只读。
