---
name: read-index-memory
description: 每个新任务开始时读取项目记忆各主题的 MEMORY.md 索引，并按索引决定是否读取正文。
---

# CodeBuddy 项目级入口

本 Skill 的脚本资源位于当前目录的 `scripts/` 子目录。

每个新任务开始时执行以下流程：

1. 运行 `python3 .codebuddy/skills/read-index-memory/scripts/read_index_memory.py`。
2. 只根据索引判断是否读取相关正文，不扫描无关正文。
3. 输出全部主题索引后，再按当前任务读取相关正文。

这是 CodeBuddy 对项目原始 Skill 的适配入口；项目记忆仍以仓库中的 `.project-memory/` 为准。
