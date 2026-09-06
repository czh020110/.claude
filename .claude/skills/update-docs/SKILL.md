---
name: update-docs
description: 当用户要求更新项目记忆文件与 git 提交说明，或需要根据当前变更生成 git commit 时使用；委托 `update-docs` agent 更新 `.project-memory/` 项目记忆与提交结果。
---

- `update-docs` agent 是一次性汇总和更新项目记忆的专用工具，只在用户主动要求时调用；不负责在开发过程中随代码变更实时调用或实时维护项目记忆。每次调用是一次性的完整流程：分析变更 → 检查文档 → 更新项目记忆 → 按需提交。
- 当前默认行为：不提交 git commit；只有提示中明确说明需要提交时才提交，默认不提交。
- 当前默认提交文件范围：全部已更改；只有用户本次要求或当前 skill prompt 明确指定/排除文件时，才改用指定/排除范围。
- 调用 `update-docs` agent 时，prompt 必须明确写明本次”需要提交 git commit”或”不要提交 git commit”，并明确写明提交文件范围是”全部已更改”还是”指定/排除文件：...”，不得只写”按默认行为”。
- 增量同步与本地变更同步：先更新项目记忆，再生成提交说明；不要先生成提交说明再更新项目记忆。

## 基准 commit 与增量同步

- 基准 commit 记录文件：`.claude/.cache/update-docs-base-commit`（一行纯文本，仅含 40 字符 SHA）
- 首次调用时若文件不存在，以当前 HEAD 初始化：`git rev-parse HEAD > .claude/.cache/update-docs-base-commit`
- 判断增量：`git rev-parse HEAD` 与基准 commit 不同 → 存在远程/历史增量提交需要同步
- 判断本地变更：`git status --short` 非空 → 存在本地未提交变更
- 即使没有增量提交（基准 == HEAD），只要存在本地未提交变更，也必须分析这些变更并检查相关文档是否需要更新；不能因为"没有新的 commit"而跳过文档检查
- 处理顺序严格为：**先增量同步，再本地变更同步**（原因：先让文档与当前 HEAD 对齐，再处理工作区变更）
- 增量同步阶段**不创建 git commit**（只更新项目记忆到工作区）
- 增量同步成功后刷新基准 commit = 当前 HEAD
- 本地变更同步阶段按顶部提交开关决定是否 commit
- 本地变更同步成功后刷新基准 commit = 新 HEAD（若提交了）

根据当前 git 变更更新 `.project-memory/` 项目记忆文件与必要的 `.claude/` 引用说明，并整理对应 git commit 的详细描述；是否提交 git commit 与提交文件范围按上方开关和用户本次要求决定；增量同步与本地变更的处理顺序按"基准 commit 与增量同步"章节决定。

# 项目记忆维护边界

- `.project-memory/Documents/`（`MEMORY.md` 纯索引 + 用户自建正文，默认只读）：用户维护的长期项目背景、需求材料、业务规则和补充说明。`update-docs` agent 默认只读——仅在正文已存在时读取内容并同步 `MEMORY.md` 索引，不新建/改写用户的正文；只有用户明确要求补充长期背景、业务边界或长期事实时，才按用户指定内容写入对应正文并同步索引。
- `.project-memory/Boundary/`（`MEMORY.md` 纯索引 + 同级正文）：项目设计边界（哪些属于项目、哪些不属于、哪些能做、哪些不能做）与验收约束；当对话、代码修改或验证结果表明当前边界、成功标准、非目标、质量底线需要调整时，提示 `update-docs` agent 更新对应正文并同步索引。
- `.project-memory/Target/`（`MEMORY.md` 纯索引 + 同级正文）：项目整体流程目标与核心功能目标；当实现过程中发现整体流程方向、需要实现的功能、阶段功能范围、目标调整或实现发现需要沉淀时，提示 `update-docs` agent 更新对应正文并同步索引。
- `.project-memory/Design/`（`MEMORY.md` 纯索引 + 同级正文）：项目架构设计与分阶段开发规划；只有当前实现与设计方案存在差异（如某模块需要新方案、技术栈变更、阶段调整）时，才提示 `update-docs` agent 更新对应正文并同步索引；不因日常代码变更而自动同步。
- git 提交说明：按一次 git commit 维度维护；当用户要求更新修改记录、总结本轮变更、整理开发记录或创建 git commit 时，提示 `update-docs` agent 生成对应 commit 的简短描述与详细描述，不再生成独立修改记录文件。

## 你的职责

- 不直接执行项目记忆更新细节；优先调用 `update-docs` agent。
- 项目记忆更新阶段应只使用自定义 subagent `update-docs`，不要改用 `general-purpose` 或其他通用 agent。
- 调用前，先判断当前项目记忆更新模式；允许只为判断记忆状态阅读相关 `.project-memory/` 文件，若 Boundary、Target 等核心规划文件仍为模板空内容，则本次更新模式为”项目记忆初始化”，否则为”项目记忆更新”；在 prompt 中明确告知 `update-docs` agent 本次更新模式。
- 调用前，必须初始化并读取基准 commit：若 `.claude/.cache/update-docs-base-commit` 不存在，执行 `git rev-parse HEAD` 写入初始化；若存在则读取当前基准 SHA。
- 调用前，必须判断增量状态：执行 `git rev-parse HEAD` 获取当前 HEAD，与基准 commit 对比，判断是否存在增量提交。
- 调用前，必须判断本地变更状态：执行 `git status --short`，判断是否存在本地未提交变更。
- 在”项目记忆初始化”模式下，不要在 prompt 中自行决定更新范围；将项目是否有代码的判断完全交给 `update-docs` agent，由其自行检查并决定更新范围。
- 调用前，把当前上下文中已知的变更背景、用户要求、已知需要更新的文件、已知需要写入/同步的内容交给 subagent；不要为了补充 prompt 主动阅读、搜索或分析代码。
- 当前 skill 自己只根据已有上下文与允许读取的项目记忆状态判断需要补充给 `update-docs` agent 的信息；代码阅读、代码搜索、变更细节确认和 git 状态分析都交给 `update-docs` agent。
- 调用 `update-docs` agent 时，必须按“Git 提交行为与文件范围开关”和用户本次要求，明确写明本次是否需要创建 git commit，以及本次提交文件范围（全部已更改、指定文件或排除文件）；用户本次要求优先于默认开关。
- `update-docs` agent 会根据上下文、git 状态和文档规则，自主判断还需要更新哪些 `.project-memory/` 文档，并在需要提交时生成对应的简短描述与详细描述。
- `update-docs` agent 不维护 `.project-memory/TODO/`（STEP.md 长期计划、TODO.md 共享待办、DONE.md 已完成归档），由你直接修改。
- 项目记忆更新完成后，只刷新基准 commit；不执行向量数据库刷新。
- 不要打断 `update-docs` agent 的执行；如果你发现用户的变更与当前项目记忆内容存在明显冲突，或者用户的要求与项目记忆维护边界不符，先在结果中报告冲突，再由 `update-docs` agent 根据规则判断如何调整更新内容或提交范围。

## 调用方式

使用 Agent 工具调用：

- `subagent_type`: `update-docs`
- `description`: `Update project memory`
- prompt 中提供：
  - 当前变更背景
  - 已知需要更新的文件
  - 已知需要写入或同步的内容
  - 本次是否需要提交 git commit（必须明确写”需要提交 git commit”或”不要提交 git commit”）
  - 本次提交文件范围（必须明确写”全部已更改”或”指定/排除文件：...”）
  - 增量同步信息：基准 commit SHA、当前 HEAD SHA、是否存在增量、增量 commit range
  - 本地变更信息：是否存在本地未提交变更
  - 处理顺序：先增量同步再本地变更同步（必须在 prompt 中写明）
  - 是否有特殊约束
  - 用户母语语言

使用的 prompt 模板：

```md
Background:

- [当前代码/文档变更背景]

Known updates:

- 文件：[已知需要更新的文件；没有明确文件则写”由 update-docs agent 根据维护边界判断”]
- 内容：[已知需要写入或同步的事实；没有则写”无”]

Base commit info:

- 基准 commit：[SHA 或”首次，无基准”]
- 当前 HEAD：[SHA]
- 存在增量提交：[是/否]（基准 != HEAD 时为是）
- 增量 commit range：[基准..HEAD，如 abc1234..def5678；无增量则写”无”]
- 存在本地未提交变更：[是/否]
- 处理顺序：先增量同步再本地变更同步

Need:

- 更新相关项目记忆与 git 提交说明
- 当前更新模式：[项目记忆初始化/项目记忆更新]
- 增量同步：[需要/不需要]；diff 来源：git diff [基准]..HEAD
- 本地变更同步：[需要/不需要]；diff 来源：git diff / git diff --staged
- 增量同步阶段：只更新项目记忆，不创建 git commit；成功后刷新基准 commit = 当前 HEAD
- 本地变更同步阶段：[需要提交 git commit / 不要提交 git commit]；原因：[用户明确要求 / 默认行为]
- 本次提交文件范围：[全部已更改 / 指定文件：... / 排除文件：...]；原因：[用户明确要求 / 默认范围]
- 如果需要提交 git commit，严格按本次提交文件范围提交；如果不要提交 git commit，只生成提交说明并明确未提交原因
- 项目记忆更新完成后，刷新基准 commit 文件 `.claude/.cache/update-docs-base-commit` 为新 HEAD 的 SHA（一行纯文本，仅含 40 字符 SHA）
- 只返回修改文件、提交结果和基准 commit 刷新结果
```

## 后续动作

项目记忆更新完成后，刷新基准 commit。

1. 刷新基准 commit：
   - 若 agent 报告增量同步成功：`git rev-parse HEAD > .claude/.cache/update-docs-base-commit`
   - 若 agent 报告增量同步失败：不刷新基准
   - 若 agent 执行了本地变更同步并成功提交了 git commit：再次 `git rev-parse HEAD > .claude/.cache/update-docs-base-commit`（因为 HEAD 已因新 commit 变化）

## 提交规则摘要

- `update-docs` agent 的提交行为和提交文件范围必须由当前 skill 在 prompt 中明确指定，不允许省略。
- 当前默认提交文件范围是**全部已更改**；如用户要求指定文件或排除文件，必须在 prompt 中列清文件范围。
- 需要提交 git commit 时，严格按指定提交文件范围提交；不要提交 git commit 时，只生成提交说明并写清未提交原因。
- 增量同步阶段**不创建 git commit**，只更新项目记忆到工作区。
- 处理顺序：先增量同步再本地变更同步，不允许颠倒。
- 详细提交说明在需要提交时写入 git commit body，不再额外创建独立修改记录文件。
- git commit 不得写入 AI 联合作者行（如 `Co-Authored-By: Claude ...`）。
- commit 描述不得涉及 `.claude/` 或 `.project-memory/` 下的文件修改。
- 如果存在明显不属于本次任务的改动，subagent 会先在结果中报告冲突，再由你决定。
- 基准 commit 文件 `.claude/.cache/update-docs-base-commit` 由 skill 在 agent 返回后根据 agent 的结果判断是否刷新；agent 自身不直接写入该文件。
- agent 必须在返回结果中明确说明增量同步是否成功；成功时 skill 刷新基准为当前 HEAD，失败时 skill 不刷新基准（下次重试）。
- 如果 agent 执行了本地变更同步并成功提交了 git commit，skill 还需额外将基准刷新为提交后的新 HEAD（`git rev-parse HEAD`）。
