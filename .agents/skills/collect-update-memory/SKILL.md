---
name: collect-update-memory
description: 仅在用户主动要求阶段性/全量同步项目记忆时使用；按顺序处理 commit、增量提交和本地变更，并委托 collect_update_memory agent。
---

# collect-update-memory

这是“全量记忆同步”的编排入口；日常局部事实用 `update-memory`。除非用户明确要求，不调用本 skill。

## 执行顺序

1. 用户同时要求 commit/提交时，先调用 `git-commit` skill；提交完成后以新的 HEAD 作为基准信息。
2. 否则不创建 commit。读取 `.codex/.cache/collect-update-memory-base-commit`；不存在时以当前 HEAD 初始化缓存并标记“首次，无基准”，再比较当前 HEAD。
3. 根据 Boundary、Target 等核心规划文件是否仍为空模板判断更新模式（初始化/更新），不要替 agent 决定初始化范围。读取 `git status --short`，把更新模式、基准 commit、当前 HEAD、是否有增量提交、本地未提交变更、已知文件/事实和用户背景传给唯一的 `collect_update_memory` agent。不要主动扫描或搜索代码来补 prompt。
4. agent 必须先同步增量提交，再同步本地未提交变更；即使没有新 commit，也不能跳过未提交检查。增量或本地阶段成功后，将基准缓存刷新为当前 HEAD；失败不刷新。
5. agent 返回后向用户转述实际修改、索引同步、增量/本地同步和验证结果。

## agent 边界

- 只能委托 `collect_update_memory`，不改用其他 agent；skill 本身不扫描或修改记忆正文。
- agent 只同步 `.project-memory/` 中当前已实施事实，不触碰 `TODO/`（包括 `Pending.md`）、`Pitfalls/`、`.project-script/`、代码或配置，不创建 commit；可读取相关正文和已有验证脚本。
- Pending 中的未实施方案、设计决策和修改要求不是事实来源；不得将其转写到任何记忆正文。Pending 的新增、完成移除或取消由主模型处理。
- `Pitfalls` 中的执行经验不由本 skill 或其 agent 新增、修改、清理或转写；由主模型在满足触发条件后使用 `update-memory` 维护。
- 没有需要持久化的事实时，允许 agent 返回“无需修改”。
