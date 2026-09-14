---
name: sync-cc-memory
description: 将 `.project-memory/` 项目记忆与 `.project-script/` 本地验证脚本作为一组，同步到独立远程 git 仓库（push / pull / info）。每个项目使用 docs 下的独立分支，支持标准 git 合并与冲突处理。用户要求同步记忆时使用。
---

# sync-cc-memory

把 `.project-memory/` 和 `.project-script/` 作为一组，同步到远程项目记忆仓库。分支由主代码仓库的 `origin` 远程 URL 唯一确定：两个目录落在同一个代码仓库对应的 `docs/<origin-url-slug>` 分支内，一起 pull/push。

## 项目标识

- 唯一标识是主代码仓库 `git remote get-url origin` 返回的 URL。
- 脚本会把这个 URL 转换成稳定的 `docs/<slug>` 分支名，并循环同步 `.project-memory/` 与 `.project-script/` 两个目录；不要再使用目录名或 `.claude/project-id`。
- 主代码仓库未配置 origin 时，脚本会直接报错，而不是回退到本地名称。

## 用法

```bash
# 从远程拉取记忆与验证脚本组到本地
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh pull

# 推送本地记忆与验证脚本组到远程
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh push

# 查看同步状态
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh info
```

## 按输出处理

脚本输出后，根据结果向用户汇报：

| 输出 | 要做 |
|---|---|
| 推送完成 / 拉取完成 / 已检出远程分支 / 已合并本地内容 | 告诉用户成功并简要说明变化 |
| 项目记忆/验证脚本无变更，无需推送 | 告诉用户对应目录无变更 |
| 参数校验失败 | 转告正确用法；若显示"URL 已配置: 否"，先配置 URL |
| 本地未提交变更 / 领先远程: N | 提示用户可用 push |
| 本地落后远程: N | 提示用户可用 pull |
| 未配置项目记忆仓库 URL | 见下方「配置 URL」 |
| 未配置 git 用户信息 | 让用户先 `git config --global user.name/email` |
| 推送失败，远程有更新未合并 | 让用户先 pull 再 push |
| 合并时出现内容冲突 | 引导手动解决（见「冲突处理」） |
| 无法访问远程项目记忆仓库 | 检查 URL、GitHub 仓库是否存在、SSH key / token |

> 若 `.project-memory/` 已有文件但还不是 git 仓库（例如刚被 sync-cc-project-config 填充模板），脚本会自动纳入版本管理并合并，无需手动处理。

## 配置 URL

当报"未配置项目记忆仓库 URL"时，让用户提供一个 GitHub/GitLab 空仓库 URL（专门存放项目记忆，不是主项目仓库）：

```bash
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh config <URL>
```

配置后重新执行 pull 或 push。

## 冲突处理

有冲突时脚本会中止，文件中留下 `<<<<<<<` / `=======` / `>>>>>>>` 标记。引导用户：

```bash
# 若冲突在 .project-memory/.git 内
cd .project-memory
# 编辑冲突文件，删除标记，保留正确内容
git add -A
git commit -m "merge: 解决 docs 冲突"
cd ..

# 若冲突在 .project-script/.git 内
cd .project-script
# 同样处理冲突并提交
cd ..
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh push
```

放弃合并：`cd .project-memory && git merge --abort`

## 其他命令

```bash
# 配置 URL（写入 .claude/.cache/docs-sync.conf，不进 git）
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh config <URL>
# 查看记忆与验证脚本组详细状态
bash .claude/skills/sync-cc-memory/scripts/sync-memory.sh status
```

跨设备：skill 随 `.claude/skills/` 同步过来；项目标识来自主仓库 origin remote，换设备无需额外配置。远程项目记忆仓库 URL 需跨设备重新配置。
