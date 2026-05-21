---
name: update-todo
description: 当模型准备开始、推进或收尾当前项目相关任务，或需要新增、开始、完成、阻塞、暂缓、整理项目 TODO 任务板时使用；通过专用 TODO 脚本结构化维护 `.claude_introduction/TODO/TODO.md`，避免手改导致编号、分区和字段不一致。
---

这是一个模型主动使用的 skill。处理当前项目相关任务时，应先判断是否需要更新 `.claude_introduction/TODO/TODO.md`，不要手改任务条目。

## 你的职责

- 在开始、推进、完成、阻塞任何与当前项目相关的任务时，主动判断是否需要更新任务板。
- 如果任务板中已有未完成任务，只在需要开始/完成/阻塞/暂缓某条任务，或出现新增需求时更新；不要覆盖原条目。
- 如果任务板中没有未完成任务，先补入下一批主任务，再继续实现。
- 优先通过脚本执行结构化修改，不直接编辑 `.claude_introduction/TODO/TODO.md`。
- 只维护当前项目任务板，不负责长期项目文档和 git 提交说明。
- 回答时说明修改了哪些任务、任务状态如何变化、以及修改了哪些文件。

## 脚本路径

- 固定脚本：`.claude/skills/update-todo/scripts/todo_cli.py`
- 默认任务板：`.claude_introduction/TODO/TODO.md`

## 支持操作

- `add`：新增任务
- `start`：把任务切到 `进行中`
- `complete`：把任务切到 `最近完成`
- `block`：把任务切到 `阻塞`
- `defer`：把任务切到 `暂缓`
- `prune-recent`：裁剪 `最近完成`

## 调用方式

优先使用 Bash 直接运行脚本，必要时可带 `--dry-run --json` 先预检。

示例：

```bash
python .claude/skills/update-todo/scripts/todo_cli.py add --title "补充恢复分支测试" --priority P1 --acceptance "新增回归可稳定通过"
python .claude/skills/update-todo/scripts/todo_cli.py start --id T-016 --progress "开始接线 recovery action"
python .claude/skills/update-todo/scripts/todo_cli.py complete --id T-016 --verification "python -m pytest tests/test_demo_run_api.py"
python .claude/skills/update-todo/scripts/todo_cli.py block --id T-017 --depends-on T-016 --note "等待恢复分支主逻辑完成"
python .claude/skills/update-todo/scripts/todo_cli.py defer --id T-017 --note "等待用户确认范围"
python .claude/skills/update-todo/scripts/todo_cli.py prune-recent --keep 12
```

## 使用规则

1. `.claude_introduction/TODO/TODO.md` 是细粒度任务的唯一事实源，不再区分独立的 TODO / DONE 文件。
2. 新任务应在准备开始实现前写入，而不是提交后再补。
3. 如果当前已有 `未开始` / `进行中` / `阻塞` / `暂缓` 任务，不要覆盖它们；只有出现新增需求时才追加任务。
4. 只有在当前没有未完成任务时，才写入下一批主任务。
5. `T-xxx` 编号一旦分配后不重排、不复用；新增任务从当前最大编号继续递增。
6. 任务状态只允许：`未开始` / `进行中` / `阻塞` / `暂缓` / `完成`。
7. `最近完成` 只保留近期完成项；过久记录可按需裁剪。
8. 完成任务时必须填写 `--verification`；有 commit 时再填写 `--commit`。
9. 若只是确认脚本效果，先用 `--dry-run --json`。
10. 若用户明确要求批量或特殊格式调整，再考虑直接编辑任务板或脚本。

## 结果要求

- 返回时简要说明：执行了什么命令、哪些任务被新增/迁移、是否成功写入。
- 如果脚本报错，先报告最小原因，再决定是否读取任务板或修脚本。
