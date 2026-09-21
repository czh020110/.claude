---
name: sync-project-memory
description: 用户要求 push、pull 或查看项目记忆同步状态时，使用独立远程 git 仓库及其 docs 分支处理 `.project-memory/`。
---

# sync-project-memory

把 `.project-memory/` 作为独立 git 仓库同步到远程项目记忆仓库。分支由主代码仓库的 `origin` 远程 URL 唯一确定：同一个代码仓库在远程记忆仓库里对应同一个 `docs/<origin-url-slug>` 分支。

## 项目标识

- 唯一标识是主代码仓库 `git remote get-url origin` 返回的 URL。
- 脚本会把这个 URL 转换成稳定的 `docs/<slug>` 分支名；不要再使用目录名或 `.agents/project-id`。
- 主代码仓库未配置 origin 时，脚本会直接报错，而不是回退到本地名称。

## 用法

入口脚本是当前 `sync-project-memory` Skill 目录下的 `scripts/sync-memory.sh`，参数为 `pull`、`push` 或 `info`。

## 按输出处理

脚本输出后，根据结果向用户汇报：

脚本输出为英文，按下表的关键字匹配向用户汇报：

| 输出关键字 | 要做 |
|---|---|
| `push complete` / `pull complete` / `checked out remote branch` / `merged local content` | 告诉用户成功并简要说明变化 |
| `has no changes, nothing to push` | 告诉用户无变更 |
| `[SYNC_ERROR] Argument validation failed` | 转告正确用法；若显示 `URL configured: no`，先配置 URL |
| `Uncommitted local changes` / `Ahead of remote: N` | 提示用户可用 push |
| `Behind remote: N` | 提示用户可用 pull |
| `Remote memory repository URL is not configured` | 见下方「配置 URL」 |
| `git user identity is not configured` | 让用户先 `git config --global user.name/email` |
| `push failed, the remote has newer commits` | 让用户先 pull 再 push |
| `hit a merge conflict` / `hit a content conflict while merging` | 引导手动解决（见「冲突处理」） |
| `Remote memory repository is not reachable` | 检查 URL、GitHub 仓库是否存在、SSH key / token |

> 若 `.project-memory/` 已有文件但还不是 git 仓库（例如刚被 `sync-project-config` 填充模板），脚本会自动纳入版本管理并合并，无需手动处理。

## 配置 URL

当输出 `Remote memory repository URL is not configured` 时，让用户提供一个 GitHub/GitLab 空仓库 URL（专门存放项目记忆，不是主项目仓库）：

配置入口是当前 `sync-project-memory` Skill 目录下的 `scripts/sync-memory.sh config <URL>`。

配置后重新执行 pull 或 push。

## 冲突处理

有冲突时脚本会中止，文件中留下 `<<<<<<<` / `=======` / `>>>>>>>` 标记。引导用户：

进入 `.project-memory/` 解决冲突后提交，再运行当前 `sync-project-memory` Skill 目录下的 `scripts/sync-memory.sh push`。

放弃合并：`cd .project-memory && git merge --abort`

## 其他命令

配置 URL 使用当前 `sync-project-memory` Skill 目录下的 `scripts/sync-memory.sh config <URL>`；查看详细状态使用同一脚本的 `status` 参数。

跨设备：Skill 随当前平台配置同步；项目标识来自主仓库 origin remote，换设备无需额外配置。远程项目记忆仓库 URL 需跨设备重新配置。
