---
name: update-docs
description: 当用户要求更新项目文档与 git 提交说明，或需要根据当前变更生成 git commit 时使用；委托 `update-docs` agent 更新 .claude_introduction 文档与提交结果，并在完成后按需调用通用 agent 直接执行 query-project 脚本同步/刷新向量库。
---

- 当前默认行为：不提交 git commit；只有提示中明确说明需要提交时才提交，默认不提交。
- 当前默认提交文件范围：全部已更改；只有用户本次要求或当前 skill prompt 明确指定/排除文件时，才改用指定/排除范围。
- 调用 `update-docs` agent 时，prompt 必须明确写明本次“需要提交 git commit”或“不要提交 git commit”，并明确写明提交文件范围是“全部已更改”还是“指定/排除文件：...”，不得只写“按默认行为”。
- 只有先更新文档，才能再根据变更生成提交说明；不要先生成提交说明再更新文档。

根据当前 git 变更更新 `.claude_introduction/` 项目文档与必要的 `.claude/` 引用说明，并整理对应 git commit 的详细描述；是否提交 git commit 与提交文件范围按上方开关和用户本次要求决定。

## 文档维护边界

- `.claude_introduction/项目文档/`：用户提供的长期项目文档目录；默认只读。只有用户明确要求更新项目文档、补充长期背景、补充业务边界或补充长期项目事实时，才提示 `update-docs` agent 写入。
- `.claude_introduction/项目实现目标/目标边界.md`：阶段边界与验收约束；当对话、代码修改或验证结果表明当前阶段目标、成功标准、非目标、质量底线或推进节奏需要调整时，提示 `update-docs` agent 更新。
- `.claude_introduction/项目实现目标/项目目标.md`：项目整体流程目标与核心功能目标；当实现过程中发现整体流程方向、需要实现的功能、阶段功能范围、目标调整或实现发现需要沉淀时，提示 `update-docs` agent 更新。
- `.claude_introduction/环境说明/本地开发环境.md`：本地环境事实；当依赖工具、运行环境、环境变量、外部服务或已知环境坑发生变化时，提示 `update-docs` agent 更新。
- `.claude_introduction/环境说明/常用命令.md`：可执行命令事实；当安装、启动、测试、类型检查、lint、构建、数据库或迁移命令发生变化时，提示 `update-docs` agent 更新。
- `.claude_introduction/数据流/核心数据流.md`：真实调用链与状态流转事实；当变更影响核心入口、输入输出、调用关系、状态变化、异常分支或验证方式时，提示 `update-docs` agent 更新对应数据流描述(不要退化为修改记录,修改记录只由git管理,只需要修改或添加当前数据流的说明)。
- `.claude_introduction/TODO/STEP.md`：长期方向和阶段步骤；只有用户要求调整长期路线、阶段计划或大方向步骤时**或者为空**时，提示 `update-docs` agent 更新。
- git 提交说明：按一次 git commit 维度维护；当用户要求更新修改记录、总结本轮变更、整理开发记录或创建 git commit 时，提示 `update-docs` agent 生成对应 commit 的简短描述与详细描述，不再生成独立修改记录文件。

## 你的职责

- 不直接执行文档更新细节；优先调用 `update-docs` agent。
- 文档更新阶段只能使用自定义 subagent `update-docs`，不要改用 `general-purpose` 或其他通用 agent；只有“后续动作”里的向量同步/刷新步骤例外，可按下文要求额外调用 `general-purpose` subagent。
- 调用前，先判断当前文档更新模式；允许只为判断文档状态阅读相关 `.claude_introduction/` 文档，若项目文档尚未初始化（目标边界、项目目标、STEP.md 仍为模板空内容），则本次更新模式为”文档初始化”，否则为”文档更新”；在 prompt 中明确告知 `update-docs` agent 本次更新模式。
- 在”文档初始化”模式下，不要在 prompt 中自行决定更新范围是否包含环境说明和数据流文档；将项目是否有代码的判断完全交给 `update-docs` agent，由其自行检查并决定更新范围（见 update-docs agent 的”文档初始化的更新范围规则”）。
- 调用前，把当前上下文中已知的变更背景、用户要求、已知需要更新的文件、已知需要写入/同步的内容交给 subagent；不要为了补充 prompt 主动阅读、搜索或分析代码。
- 当前 skill 自己只根据已有上下文与允许读取的文档状态判断需要补充给 `update-docs` agent 的信息；代码阅读、代码搜索、变更细节确认和 git 状态分析都交给 `update-docs` agent。
- 调用 `update-docs` agent 时，必须按“Git 提交行为与文件范围开关”和用户本次要求，明确写明本次是否需要创建 git commit，以及本次提交文件范围（全部已更改、指定文件或排除文件）；用户本次要求优先于默认开关。
- `update-docs` agent 会根据上下文、git 状态和文档规则，自主判断还需要更新哪些 `.claude_introduction/` 文档，并在需要提交时生成对应的简短描述与详细描述。
- `update-docs` agent 完成文档更新和提交后，如果本次改动更新了 `.claude_introduction/` 下真实事实文档，由当前 skill 额外调用一个通用 subagent 执行 query-project 脚本的配置状态同步与向量刷新；prompt 中必须直接写明固定命令，禁止让 subagent 自行查找脚本、命令或路径。
- 不要打断 `update-docs` agent 的执行；如果你发现用户的变更与当前文档内容存在明显冲突，或者用户的要求与文档维护边界不符，先在结果中报告冲突，再由 `update-docs` agent 根据规则判断如何调整更新内容或提交范围。

## 调用方式

使用 Agent 工具调用：

- `subagent_type`: `update-docs`
- `description`: `Update project docs`
- prompt 中提供：
  - 当前变更背景
  - 已知需要更新的文件
  - 已知需要写入或同步的内容
  - 本次是否需要提交 git commit（必须明确写“需要提交 git commit”或“不要提交 git commit”）
  - 本次提交文件范围（必须明确写“全部已更改”或“指定/排除文件：...”）
  - 是否有特殊约束

推荐 prompt 模板：

```md
Background:

- [当前代码/文档变更背景]

Known updates:

- 文件：[已知需要更新的文件；没有明确文件则写“由 update-docs agent 根据维护边界判断”]
- 内容：[已知需要写入或同步的事实；没有则写“无”]

Need:

- 更新相关 introduction 文档与 git 提交说明
- 本次更新模式：[文档初始化/文档更新]
- 本次提交行为：[需要提交 git commit / 不要提交 git commit]；原因：[用户明确要求 / 按 skill 顶部默认行为开关]
- 本次提交文件范围：[全部已更改 / 指定文件：... / 排除文件：...]；原因：[用户明确要求 / 按 skill 顶部默认文件范围开关]
- 如果需要提交 git commit，严格按本次提交文件范围提交；如果不要提交 git commit，只生成提交说明并明确未提交原因
- 只返回修改文件、验证结果、提交结果、以及是否已执行 query-project 配置同步 / 向量刷新与对应结果
```

## 后续动作

如果 `update-docs` agent 完成了 `.claude_introduction/` 下真实事实文档更新，当前 skill 应额外调用一个通用 subagent 处理向量数据库刷新。

1. 使用 Agent 工具调用：
   - `subagent_type`: `general-purpose`
   - `description`: `Refresh query-project RAG`
2. prompt 中必须直接写明以下命令示例，并明确要求 subagent 直接执行，不要自行查找脚本、命令或路径；解释时强调 `python` 只是示例占位，实际应使用当前环境可用的 Python 解释器：

```bash
python .claude/skills/query-project/scripts/query_introduction_rag.py --sync-config-status
python .claude/skills/query-project/scripts/query_introduction_rag.py --refresh-index
```

3. 执行顺序要求：
   - 先执行 `--sync-config-status`
   - 只有返回状态为 `(rag已配置)` 时，才继续执行 `--refresh-index`
4. 固定脚本路径为：`.claude/skills/query-project/scripts/query_introduction_rag.py`。
5. subagent 返回时只需要说明：执行了哪些命令、是否检测到 `(rag已配置)`、是否成功刷新、如失败给出最小原因。

## 提交规则摘要

- `update-docs` agent 的提交行为和提交文件范围必须由当前 skill 在 prompt 中明确指定，不允许省略。
- 当前默认提交文件范围是**全部已更改**；如用户要求指定文件或排除文件，必须在 prompt 中列清文件范围。
- 需要提交 git commit 时，严格按指定提交文件范围提交；不要提交 git commit 时，只生成提交说明并写清未提交原因。
- 详细提交说明在需要提交时写入 git commit body，不再额外创建独立修改记录文件。
- 如果存在明显不属于本次任务的改动，subagent 会先在结果中报告冲突，再由你决定。
