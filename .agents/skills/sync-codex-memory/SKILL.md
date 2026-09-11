---
name: sync-codex-memory
description: 将 `.project-memory/` 项目记忆与独立远程 git 仓库同步（push / pull / info）。每个项目使用 docs 下的独立分支，支持标准 git 合并与冲突处理。用户要求同步记忆时使用。
---

# sync-codex-memory

把 `.project-memory/` 作为独立 git 仓库同步到远程项目记忆仓库的 `docs/<project-id>` 分支。

## 用法

```bash
# 从远程拉取项目记忆到本地
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh pull

# 推送本地项目记忆到远程
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh push

# 查看同步状态
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh info
```

## 按输出处理

脚本输出后，根据结果向用户汇报：

| 输出 | 要做 |
|---|---|
| 推送完成 / 拉取完成 / 已检出远程分支 / 已合并本地内容 | 告诉用户成功并简要说明变化 |
| 项目记忆无变更，无需推送 | 告诉用户无变更 |
| 参数校验失败 | 转告正确用法；若显示"URL 已配置: 否"，先配置 URL |
| 本地未提交变更 / 领先远程: N | 提示用户可用 push |
| 本地落后远程: N | 提示用户可用 pull |
| 未配置项目记忆仓库 URL | 见下方「配置 URL」 |
| 未配置 git 用户信息 | 让用户先 `git config --global user.name/email` |
| 推送失败，远程有更新未合并 | 让用户先 pull 再 push |
| 合并时出现内容冲突 | 引导手动解决（见「冲突处理」） |
| 无法访问远程项目记忆仓库 | 检查 URL、GitHub 仓库是否存在、SSH key / token |

> 若 `.project-memory/` 已有文件但还不是 git 仓库（例如刚被 sync-codex-project-config 填充模板），脚本会自动纳入版本管理并合并，无需手动处理。

## 配置 URL

当报"未配置项目记忆仓库 URL"时，让用户提供一个 GitHub/GitLab 空仓库 URL（专门存放项目记忆，不是主项目仓库）：

```bash
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh config <URL>
```

配置后重新执行 pull 或 push。

## 冲突处理

有冲突时脚本会中止，文件中留下 `<<<<<<<` / `=======` / `>>>>>>>` 标记。引导用户：

```bash
cd .project-memory
# 编辑冲突文件，删除标记，保留正确内容
git add -A
git commit -m "merge: 解决 docs 冲突"
cd ..
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh push
```

放弃合并：`cd .project-memory && git merge --abort`

## 其他命令

```bash
# 配置 URL（写入 .codex/.cache/docs-sync.conf，不进 git）
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh config <URL>
# 查看详细 git 状态
bash .agents/skills/sync-codex-memory/scripts/sync-memory.sh status
```

跨设备：skill 随 `.agents/skills/` 同步过来，`.codex/project-id` 随主项目 git 同步；但项目记忆仓库 URL 需跨设备重新配置。
