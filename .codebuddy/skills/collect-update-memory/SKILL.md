---
name: collect-update-memory
description: 仅在用户主动要求阶段性或全量同步项目记忆时，按顺序同步已实施项目事实。
---

# CodeBuddy 项目级入口

只有用户明确要求阶段性/全量同步项目记忆时使用：

1. 用户同时要求提交时，先执行 `git-commit`。
2. 读取当前 HEAD、基准缓存和工作区状态，按“增量提交后再本地变更”的顺序组织上下文。
3. 调用项目子代理 `collect-update-memory`。
4. 代理只更新 `.project-memory/` 中已实施事实，不修改 TODO/Pending、Pitfalls、验证脚本、代码、配置或 git 状态。
5. 返回实际修改、索引同步和验证结果；没有事实变化时允许不修改。

增量基准缓存使用 `.codebuddy/.cache/collect-update-memory-base-commit`；Pending/TODO、Pitfalls、验证脚本、代码、配置和提交仍不由该代理维护。
