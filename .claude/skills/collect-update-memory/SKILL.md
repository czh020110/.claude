---
name: collect-update-memory
description: 当用户要求更新项目记忆文件与 git 提交说明，或需要根据当前变更生成 git commit 时使用；委托 `collect-update-memory` agent 更新 `.project-memory/` 项目记忆与提交结果。
---

# 定位

- 只在用户主动要求时调用（阶段性汇总、提交说明、git commit）；不负责开发过程中随代码变更实时维护项目记忆——实时局部更新使用 `update-memory` skill。

## 你的职责

- 不直接执行项目记忆更新细节，只负责调用 `collect-update-memory` agent（不要改用 `general-purpose` 或其他 agent），并把正确的信息交给它；更新细节、提交顺序与提交行为由 agent 按其提示词自行控制。
- 调用前判断更新模式：若 Boundary、Target 等核心规划文件仍为模板空内容，则为”项目记忆初始化”，否则为”项目记忆更新”；初始化模式下不要在 prompt 中自行决定更新范围，交给 agent 判断。
- 不为补充 prompt 主动阅读、搜索或分析代码；只把当前上下文已知的变更背景、用户要求、已知文件与内容交给 agent。

## commit 决策（MUST）

- 默认不提交；只有用户本次明确要求提交时才提交。文件范围默认全部已更改，用户本次指定/排除范围时按指定范围。
- prompt 必须明确写明本次”需要提交 git commit”或”不要提交 git commit”，以及提交文件范围，不得只写”按默认行为”。

## 基准 commit 管理（skill 端执行）

- 缓存文件 `.claude/.cache/collect-update-memory-base-commit`（一行 40 字符 SHA）由 skill 端读写，agent 不直接写入。
- 调用前：文件不存在则以当前 HEAD 初始化；存在则读取基准 SHA。`git rev-parse HEAD` != 基准 → 存在增量提交；`git status --short` 非空 → 存在本地未提交变更。两项结果写进 prompt。
- agent 返回后刷新：增量同步成功 → 刷新为当前 HEAD；本地变更同步并提交了 commit → 刷新为提交后的新 HEAD；失败不刷新（下次重试）。

## 调用方式

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
- 当前 HEAD：[SHA]
- 存在增量提交：[是/否]；增量 commit range：[基准..HEAD，无增量则写”无”]
- 存在本地未提交变更：[是/否]
- 处理顺序：先增量同步再本地变更同步

Need:

- 更新相关项目记忆与 git 提交说明
- 当前更新模式：[项目记忆初始化/项目记忆更新]
- [需要提交 git commit / 不要提交 git commit]；本次提交文件范围：[全部已更改 / 指定文件：... / 排除文件：...]
- 只返回修改文件、提交结果，并明确说明增量同步是否成功；基准 commit 由 skill 端刷新，agent 不直接写入该文件
```
