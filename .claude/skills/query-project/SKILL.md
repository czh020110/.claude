---
name: query-project
description: 当用户要求查询项目背景、目标、模块规划、环境、数据流、TODO/DONE、修改记录，或模型需要按问题从 introduction/ 项目事实文档中检索上下文时使用；主模型应委托 query-project-agent 执行 RAG 检索并返回相关文档块摘要 (rag已配置)
---

基于 `introduction/` 下的项目事实文档做只读 RAG 检索。

## 主模型职责

- 不直接执行 RAG 脚本；优先调用 `query-project-agent`。
- 只能使用自定义 subagent `query-project-agent`，不要改用 `general-purpose` 或其他通用 agent。
- 可以一次提交一个或多个问题给 `query-project-agent`，让 subagent 批量检索、去重、提炼结果。
- 只要求 subagent 返回与问题相关的文档块内容、路径、行号和必要分数。
- 收到 subagent 结果后，主模型再结合当前任务做最终回答或实施决策。
- 如果 subagent 返回 `CONFIG_ERROR[...]`，主模型读取 `references/api-config-guide.md` 并继续用户配置引导。
- 如果 subagent 返回 `GITIGNORE_ERROR`，主模型先补齐根目录 `.gitignore` 缺失条目，再重新委托。

## 调用方式

使用 Agent 工具调用：

- `subagent_type`: `query-project-agent`
- `description`: `Query project docs`
- prompt 中只需要提供问题列表和结果要求。
- 不要写“按 `.claude/agents/query-project-agent.md` 的流程执行”。
- 不要使用 `general-purpose` 或其他通用 subagent 代替。

推荐 prompt 模板：

```md
Questions:
1. [问题 1]
2. [问题 2]

Need:
- 只返回与问题直接相关的文档块内容、路径、行号和必要分数。
- 多问题结果按问题分组，跨问题去重。
- 每个问题都要给出结论 / 依据 / 后续，形成闭环。
```

## 什么时候调用

- 用户要求查询项目背景、目标、模块规划、环境、数据流、TODO/DONE、修改记录。
- 模型执行任务时需要确认项目细节，例如模块边界、数据流入口、已完成事项、当前目标或环境命令。
- 更新文档前后需要确认 `introduction/` 中真实项目事实。

## 主模型后续动作

- 如果 subagent 返回检索结果，主模型基于这些结果回答用户或继续执行当前任务。
- 如果 subagent 返回 `CONFIG_ERROR[...]`，由主模型负责继续配置引导，不要把这部分交给 subagent。
- 如果主模型修复了配置，先运行 `--sync-config-status`；若状态为 `(rag已配置)`，再按需运行 `--refresh-index`。

## 结果使用规则

1. 优先使用 subagent 返回的最高相关文档块。
2. 回答项目事实时带上文件路径和行号。
3. 如果 subagent 表示检索不足，不要猜测；读取对应原文或询问用户。
4. 不要把 API key、embedding 向量、完整索引内容写入回答。

## 维护说明

- query-project 的执行细节已经完全收敛到 `.claude/agents/query-project-agent.md`。
- `references/api-config-guide.md` 只服务于主模型的用户配置引导，不是 subagent 执行 reference。
- 本 skill 的主用途是提示主模型直接委托自定义 subagent `query-project-agent`，避免用通用 agent 额外读取 agent 文件、增加 token 消耗，且不把脚本操作细节加载进主模型上下文。
