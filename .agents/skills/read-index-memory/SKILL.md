---
name: read-index-memory
description: 当需要读取项目记忆索引时使用。读取 `.project-memory/` 下所有主题的 `MEMORY.md` 索引内容（不含 `DONE.md`），供主模型根据索引按需读取正文。任务开始、`任务执行流程（MUST）` 或需要判断从哪个记忆主题深入时调用。
---

# 用途

`.project-memory/` 采用「索引 + 分块文件」范式，Codex 不会像 Claude Code 那样自动把记忆索引注入每次对话。本 skill 用一个跨平台脚本把所有主题的 `MEMORY.md` 索引一次性读出来，让主模型先看到索引路由信息，再按需读取具体正文。

只读取**索引内容**（每个主题目录下的 `MEMORY.md`），不读取正文文件，也不读取 `.project-memory/TODO/DONE.md`。

# 触发时机

- 每次开始新任务，判断是否涉及项目记忆时。
- `任务执行流程（MUST）` 第 2 步“读取记忆”时，先调用本 skill 读索引，再按索引决定读取哪些正文。
- 需要定位某类记忆应读取哪个主题、哪个正文文件时。

# 执行

使用 Python 脚本读取索引，保证跨平台（Windows/macOS/Linux）可运行：

```bash
python3 .agents/skills/read-index-memory/scripts/read_index_memory.py
```

脚本不会修改、创建、删除任何文件，只输出索引内容。

# 输出与后续动作

脚本输出每个主题 `MEMORY.md` 的完整内容（路径 + 内容），并标注哪些正文文件按索引判断需要读取。主模型根据索引中的覆盖范围、关键对象和读取条件，决定下一步要读取哪些正文文件。

# 边界（MUST）

- 不读取 `.project-memory/TODO/DONE.md`：已完成任务归档由主模型直接打开文件读取，不由本 skill 负责。
- 不读取 `.project-memory/` 下的正文文件，除非按索引命中后另行读取。
- 不读取 `.project-script/MEMORY.md`：那是验证脚本索引，不是项目记忆索引。
- 不修改任何文件，不作为 agent 调用，由主模型直接执行。
