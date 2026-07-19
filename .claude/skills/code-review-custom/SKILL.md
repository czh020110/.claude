---
name: code-review-custom
description: 对指定范围的代码进行审查，判断修改是否正确、能否按预期实现功能。必须委托 code-review-custom agent 执行，不使用其他 agent。
---

对指定范围的代码进行审查，判断修改是否正确、能否按预期实现功能。

## 你的职责

1. **确定审查范围**，必须明确传给 agent：
   - 用户说"审查当前修改"→ 工作区变更：`git diff` + `git diff --staged`
   - 用户说"审查最近 N 次提交"→ `HEAD~N..HEAD`
   - 用户给出具体 commit SHA → `SHA1..SHA2` 或单个 SHA
   - 用户说"审查某个文件"→ 指定文件路径
   - **不要自行猜测范围**，如果用户没说清楚，先问用户
2. **必须委托 `code-review-custom` agent**，不使用其他 code-review agent
3. 收到结果后，向用户转述审查结论

## 调用方式

使用 Agent 工具，`subagent_type` 必须为 `code-review-custom`，prompt 中必须包含：

- **审查范围**（必填）：明确告诉 agent 审查哪些代码
- **修改意图**（可选）：如果用户说明了意图，一并传入；否则让 agent 从 diff 推断

示例：

```
审查范围：当前工作区变更（git diff + git diff --staged）
修改意图：[用户说明的意图，或留空]
```

```
审查范围：HEAD~3..HEAD
修改意图：[用户说明的意图，或留空]
```

```
审查范围：文件 .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh 的 HEAD~1..HEAD 变更
修改意图：修复空参时不显示 URL 配置状态的问题
```

## 结果处理

收到 agent 返回的审查结果后：

- **有 P0/P1 问题**：向用户明确报告，说明需要修改
- **只有 P2/P3 问题**：向用户报告，由用户决定是否修改
- **未发现问题**：告诉用户审查通过

不要自行修改代码，只报告审查结果。
