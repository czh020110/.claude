---
name: sync-project-memory
description: 用户要求 push、pull 或查看项目记忆同步状态时，使用项目记忆专用远程仓库。
---

# CodeBuddy 项目级入口

仅在用户明确要求同步项目记忆时执行：

- 查看状态：`bash .codebuddy/skills/sync-project-memory/scripts/sync-memory.sh info`
- 拉取远程：`bash .codebuddy/skills/sync-project-memory/scripts/sync-memory.sh pull`
- 推送本地：`bash .codebuddy/skills/sync-project-memory/scripts/sync-memory.sh push`

按脚本输出报告配置、领先/落后、冲突和凭据问题；不要把项目记忆同步误当成主仓库提交。
