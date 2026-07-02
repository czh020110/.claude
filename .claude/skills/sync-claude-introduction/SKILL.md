---
name: sync-claude-introduction
description: 将 .claude_introduction/ 项目文档与独立远程 git 仓库同步（push / pull），或查看同步状态（info），每个项目使用独立分支，支持真正的 git 合并与冲突处理。
disable-model-invocation: true
---

# sync-claude-introduction

把 `.claude_introduction/` 作为独立 git 仓库同步到远程文档仓库的
`docs/<project-id>` 分支。用法：

```
/sync-claude-introduction pull     从远程拉取文档到本地
/sync-claude-introduction push     把本地文档推送到远程
/sync-claude-introduction info     查看同步状态（本地/远程是否有更新）
```

## 执行结果（加载时已自动执行并注入）

脚本在本 skill 加载前已用用户传入的方向自动执行，输出如下。模型**不要自己
跑命令**，直接读下面输出按表处理：

```!
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh $ARGUMENTS || true
```

`|| true` 防止脚本非零退出阻塞加载，错误原因已在输出里。

## 按输出结果处理

| 输出标记 | 你要做的 |
|---|---|
| `推送完成` / `拉取完成` / `已检出远程分支` / `已合并本地内容` | 告诉用户成功，简要说明更新/推送/合并了哪些文件 |
| `文档内容无变更，无需推送` | 告诉用户无需推送 |
| `[SYNC_ERROR] 参数校验失败` | 原样转告用户，让他用 `pull` / `push` / `info` 重新调用。**若同时显示"URL 已配置: 否"**，先引导配置 URL（见下） |
| `本地未提交变更: 有` / `本地领先远程: N`（info 输出）| 告诉用户本地有未推送的内容，可用 `push` 同步 |
| `本地落后远程: N`（info 输出）| 告诉用户远程有未拉取的更新，可用 `pull` 同步 |
| `未配置远程文档仓库 URL` | 见下方「配置 URL」 |
| `未配置 git 用户信息` | 让用户运行 `git config --global user.name/email` 后重新调用 |
| `推送失败，远程有更新未合并` | 让用户先 `/sync-claude-introduction pull`，解决冲突后再 push |
| `合并时出现内容冲突…冲突文件:`（同名文件两边都改过）| 引导用户解决冲突（见下）；或让用户决定放弃本地用远程覆盖 |
| `无法访问远程仓库` | 让用户检查 URL、是否在 GitHub 建了空仓库、SSH key / token |

> **关于本地已有内容**：若 `.claude_introduction/` 已有文件但还不是 git 仓库
> （例如刚被 `sync-claude-config` 填充模板），pull/push 会**自动 git init 并
> 合并**——不同文件自动并存，只有同名文件两边都改过才需手动解决。模型不需要
> 让用户选方案，脚本直接处理。

## 配置 URL（仅当输出报"未配置 URL"时）

让用户提供一个 GitHub/GitLab **空仓库** URL（专门放各项目文档，与主项目
代码仓库不是同一个），形如 `https://github.com/用户名/仓库.git`。拿到后跑：

```bash
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh config <URL>
```

配置后让用户重新运行 `/sync-claude-introduction pull` 或 `push`。不要凭空
假设或写入未经用户确认的 URL。

## 冲突处理

pull 产生冲突时脚本会中止，文档里留下 `<<<<<<<` / `=======` / `>>>>>>>`
标记。引导用户：

```bash
cd .claude_introduction
# 编辑冲突文件，删除标记，保留正确内容
git add -A
git commit -m "merge: 解决 docs 冲突"
cd ..
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh push
```

放弃合并：`cd .claude_introduction && git merge --abort`

## 其他命令（用户主动问时再用）

```bash
# 配置文档仓库 URL（写入 .claude/.cache/docs-sync.conf，不进 git）
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh config <URL>
# 查看详细 git 状态（含完整 git status 输出，比 info 更详细）
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh status
```

跨设备：换新设备时脚本由 `.claude/` 同步 skill 带过来，`.claude/project-id`
随主项目 git 自动过来；但文档仓库 URL 需重新配置一次（本 skill 会报
"未配置 URL"提示）。详细前置配置见仓库内 `.claude/skills/sync-claude-introduction/` 的相关文档。
