---
name: sync-claude-config
description: 从 GitHub 仓库同步 .claude/ 和 .claude_introduction/ 配置文件到当前项目。支持智能合并策略，自动管理 .gitignore。
disable-model-invocation: true
---

# sync-claude-config 同步结果

以下同步操作已在 skill 加载时自动执行完成：

```!
bash ~/.claude/skills/sync-claude-config/scripts/sync.sh
```

## 你的任务

请根据上述执行日志，向用户汇报同步结果：

1. 是否有文件变更（新增/覆盖/跳过）
2. 变更的文件列表摘要
3. .gitignore 是否有更新
4. 如果有错误，说明错误原因

**注意**：同步操作已完成，你只需要汇报结果，不需要执行任何命令。
