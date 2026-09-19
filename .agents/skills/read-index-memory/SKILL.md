---
name: read-index-memory
description: 每个新任务开始时读取 `.project-memory/` 各主题的 `MEMORY.md` 索引，并按索引决定是否读取正文。
---

# 用途

`.project-memory/` 采用“索引 + 分块正文”。本 skill 只读取各主题的 `MEMORY.md`，让模型先获得路由信息，再按需读取相关正文；不要因为调用本 skill 就扫描所有正文。

此脚本只读取**索引内容**（每个主题目录下的 `MEMORY.md`），不读取正文文件。

`Pitfalls` 与其他顶层主题同级；只有任务涉及重复性执行经验、记忆维护或相关规避方式时，才根据其索引读取对应正文，不因目录存在而扫描全部执行经验正文。

# 执行

使用 Python 脚本读取索引，保证跨平台（Windows/macOS/Linux）可运行：

```bash
python3 .agents/skills/read-index-memory/scripts/read_index_memory.py
```

脚本不会修改、创建、删除任何文件，只输出索引内容。不要此脚本的源代码。只需要获取脚本的执行结果。

# 输出与后续动作

脚本输出每个主题 `MEMORY.md` 的完整内容（路径 + 内容）。根据索引的覆盖范围、关键对象和读取条件，结合当前任务决定下一步要读取哪些正文文件；无匹配主题时不读取正文。
