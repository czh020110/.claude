---
name: design-project
description: 当用户要求设计项目架构、生成项目设计方案、初始化项目设计，或用户提供了项目需求描述需要生成架构设计时使用；委托 `design-project` agent 根据 .claude_introduction/ 文档生成项目架构设计方案，写入 .claude_introduction/项目设计/项目设计.md。
---

## 触发条件

- 用户要求"设计项目""生成项目设计""初始化项目设计""架构设计"等。
- 用户提供了项目需求描述并希望基于此生成架构设计方案。
- `.claude_introduction/项目设计/项目设计.md` 为空，且用户需要项目设计。

## 前置检查

1. 读取 `.claude_introduction/项目设计/项目设计.md`，若已有非空内容（模板除外），停止并告知用户"项目设计文件已有内容，如需重新设计请先清空该文件"。
2. 检查 `.claude_introduction/` 下是否存在项目文档（项目目标、目标边界等）；若完全为空模板，告知用户"项目文档尚未初始化，请先补充项目需求信息"。

## 你的职责

- 不直接执行设计细节；必须调用 `design-project` agent。
- 只能使用自定义 subagent `design-project`，不要改用 `general-purpose` 或其他通用 agent。
- 调用前，把当前上下文中已知的项目需求描述、用户补充的约束条件交给 subagent。
- 如果用户在对话中直接描述了项目需求（如"我需要做一个XXX系统"），必须将该描述完整传入 agent prompt 中。
- 不要为了补充 prompt 主动阅读或搜索代码；代码阅读和代码搜索都严禁，设计只能基于文档。

## 调用方式

使用 Agent 工具调用：

- `subagent_type`: `design-project`
- `description`: `Generate project architecture design`
- prompt 中提供：
  - 用户提供的项目需求描述（如有）
  - 用户补充的约束条件（如团队规模、成本限制、技术偏好等，如有）
  - 已知的项目文档状态（哪些文档已有内容、哪些仍为空模板）

推荐 prompt 模板：

```md
Project design request:

- User description: [用户提供的项目需求描述；若用户未提供则写"无，由 agent 根据 .claude_introduction/ 文档自行分析"]
- Constraints: [用户补充的约束条件；无则写"无"]
- Document status: [哪些 .claude_introduction/ 文档已有内容，哪些仍为空模板]

Instructions:

- 根据 .claude_introduction/ 目录下的所有项目文档生成项目架构设计方案
- 若用户提供了项目需求描述，将其作为设计的重要输入
- 设计结果写入 .claude_introduction/项目设计/项目设计.md
- 只允许写入该单一文件，不允许修改其他文件或代码
- 只允许读取文档，严禁查看任何源代码文件
```

## 后续动作

- agent 完成后，告知用户设计已写入 `.claude_introduction/项目设计/项目设计.md`，建议用户审阅并根据实际情况调整。
- 不自动触发其他 skill（如 update-docs、update-todo）；用户如需后续操作另行指示。
