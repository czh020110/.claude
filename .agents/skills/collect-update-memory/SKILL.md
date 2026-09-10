---
name: collect-update-memory
description: 当用户要求阶段性汇总并更新项目记忆时使用；委托 `collect-update-memory` agent 全量同步 `.project-memory/` 项目记忆。git commit 由本 skill 在调用 agent 前通过 `git-commit` skill 完成。
---

# 定位

- 只在用户主动要求时调用（阶段性汇总、全量同步记忆）；不负责开发过程中随代码变更实时维护项目记忆——实时局部更新使用 `update-memory` skill。
- `collect-update-memory` agent 只更新项目记忆，不创建 git commit、不生成提交说明。

# 执行顺序（MUST）

1. **用户本次要求提交 git commit 时**：先使用 `git-commit` skill 创建 commit（含提交说明），再调用 `collect-update-memory` agent 更新记忆——保证记忆文档反映 commit 后的最新状态。
2. **用户本次不要求提交时**：跳过 commit，直接调用 `collect-update-memory` agent 更新记忆。

# 你的职责

- 不直接执行项目记忆更新细节，只负责按上述顺序调用 skill 和 agent（agent 只用 `collect-update-memory`，不要改用 `general-purpose` 或其他 agent），并把正确的信息交给它；记忆更新细节由 agent 按其提示词自行控制。
- 调用前判断更新模式：若 Boundary、Target 等核心规划文件仍为模板空内容，则为”项目记忆初始化”，否则为”项目记忆更新”；初始化模式下不要在 prompt 中自行决定更新范围，交给 agent 判断。
- 不为补充 prompt 主动阅读、搜索或分析代码；只把当前上下文已知的变更背景、用户要求、已知文件与内容交给 agent。

# 基准 commit 管理（skill 端执行）

- 缓存文件 `.codex/.cache/collect-update-memory-base-commit`（一行 40 字符 SHA）由 skill 端读写，agent 不直接写入。
- 调用前：文件不存在则以当前 HEAD 初始化；存在则读取基准 SHA。`git rev-parse HEAD` != 基准 → 存在增量提交；`git status --short` 非空 → 存在本地未提交变更。两项结果写进 prompt。
- 先用 git-commit skill 提交了 commit 时，以提交后的新 HEAD 作为当前 HEAD 写进 prompt。
- agent 返回后刷新：增量同步成功 → 刷新为当前 HEAD；本地变更同步成功 → 刷新为执行后的 HEAD；失败不刷新（下次重试）。

# 调用方式

使用 Agent 工具调用：`subagent_type: collect-update-memory`，`description: Collect and Update all project memory`。

prompt 模板：

```md
Background:

- [当前代码/文档变更背景]

Known updates:

- 文件：[已知需要更新的文件；没有明确文件则写”由 collect-update-memory agent 根据维护边界判断”]
- 内容：[已知需要写入或同步的事实；没有则写”无”]

Base commit info:

- 基准 commit：[SHA 或”首次，无基准”]
- 当前 HEAD：[SHA；若已先完成 commit 则为新 HEAD]
- 存在增量提交：[是/否]；增量 commit range：[基准..HEAD，无增量则写”无”]
- 存在本地未提交变更：[是/否；先 commit 后为否]
- 处理顺序：先增量同步再本地变更同步

Need:

- 更新相关项目记忆（只更新记忆，不创建 git commit）
- 当前更新模式：[项目记忆初始化/项目记忆更新]
- 只返回修改文件，并明确说明增量同步是否成功；基准 commit 由 skill 端刷新，agent 不直接写入该文件
```
