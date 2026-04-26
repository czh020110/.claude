---
name: update-docs
description: 只有当用户要求更新项目文档、TODO/DONE、修改记录，或要求根据本次变更生成 git commit 时使用；主模型应委托 `update-docs` agent 更新 introduction 文档与提交结果，并在其完成后自行决定是否触发 query-project 向量刷新。
---

根据当前 git 变更更新 `.claude/introduction/` 项目文档、TODO/DONE、修改记录，并在用户要求提交时创建 git commit。

## 主模型职责

- 不直接执行文档更新细节；优先调用 `update-docs` agent。
- 只能使用自定义 subagent `update-docs` agent，不要改用 `general-purpose` 或其他通用 agent。
- 主模型只需要把当前已知的变更背景、用户要求和是否需要提交交给 subagent。
- subagent 会根据自己的上下文、git 状态和文档规则，自主判断需要更新哪些 `introduction/` 文档。
- `update-docs` agent 完成文档更新和提交后，主模型再决定是否调用 `query-project` 刷新向量数据库。

## 调用方式

使用 Agent 工具调用：

- `subagent_type`: `update-docs`
- `description`: `Update project docs`
- prompt 中只需要提供：
  - 当前变更背景
  - 需要同步的文档范围
  - 是否需要提交
  - 是否有特殊约束

推荐 prompt 模板：

```md
Background:
- [当前代码/文档变更背景]

Need:
- 更新相关 introduction 文档、TODO/DONE、修改记录
- [是否需要提交]
- 只返回修改文件、验证结果、提交结果、以及是否建议主模型触发 query-project 向量刷新
```

## 什么时候调用

- 用户要求更新项目文档。
- 用户要求更新 TODO/DONE。
- 用户要求生成修改记录。
- 用户要求基于当前变更创建 git commit。

## 主模型后续动作

如果 `update-docs` agent 完成了 `introduction/` 下真实事实文档更新，主模型应在其完成后单独处理向量数据库：

1. 调用 `query-project` 执行配置状态同步。
2. 如果状态为 `(rag已配置)`，再调用刷新脚本更新向量数据库。
3. 这一步不由 `update-docs` agent 执行。

## 提交规则摘要

- `update-docs` agent 在用户要求提交时，优先提交**全部已更改**，而不是部分提交。
- 如果存在明显不属于本次文档工作的改动，subagent 会先在结果中报告冲突，再由主模型决定。

## 维护说明

- 详细文档格式、TODO/DONE 轮转、修改记录规则、提交规则都已迁移进 `.claude/agents/update-docs.md`。
- 本 skill 的主用途是提示主模型直接委托自定义 subagent `update-docs` agent，避免把文档更新细节加载进主模型上下文。
