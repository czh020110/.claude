---
name: read-index-memory
description: 当需要读取项目记忆索引时使用。读取 `.project-memory/` 下所有主题的 `MEMORY.md` 索引内容（不含 `DONE.md`），供主模型根据索引按需读取正文。任务开始、`任务执行流程（MUST）` 或需要判断从哪个记忆主题深入时调用。
---

# 用途

`.project-memory/` 采用「索引 + 分块文件」范式。本 skill 用一个跨平台脚本把所有主题的 `MEMORY.md` 索引一次性读出来，让主模型先看到索引路由信息，再按需读取具体正文。

此脚本只读取**索引内容**（每个主题目录下的 `MEMORY.md`），不读取正文文件，也不读取 `.project-memory/TODO/DONE.md`。

# 执行

使用 Python 脚本读取索引，保证跨平台（Windows/macOS/Linux）可运行：

```bash
python3 .agents/skills/read-index-memory/scripts/read_index_memory.py
```

脚本不会修改、创建、删除任何文件，只输出索引内容。

# 输出与后续动作

脚本输出每个主题 `MEMORY.md` 的完整内容（路径 + 内容），并标注哪些正文文件按索引判断需要读取。你需要根据索引中的覆盖范围、关键对象和读取条件，决定下一步要读取哪些正文文件。
