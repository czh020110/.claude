---
name: sync-claude-introduction
description: 将 .claude_introduction/ 项目文档与独立远程 git 仓库同步（push / pull），每个项目使用独立分支，支持真正的 git 合并与冲突处理。
---

# sync-claude-introduction

此技能将当前项目的 `.claude_introduction/` 作为**一个独立的 git 仓库**管
理（不依赖缓存目录或文件复制），远程仓库中使用独立分支区分不同项目，
`pull`/`push` 使用标准 git 语义，支持真正的合并与冲突处理。

## 工作原理

```
远程仓库 (claude-project-docs)
├── docs/<project-id-A>   ← 项目 A 的文档分支
├── docs/<project-id-B>   ← 项目 B 的文档分支
└── ...

本地项目:
  .claude_introduction/
  ├── .git                ← 独立 git 仓库，指向远程 docs/<project-id>
  ├── 项目文档/
  ├── 项目边界/
  └── ...
```

- `pull` = `git pull --no-rebase origin docs/<project-id>` — **真实合并，支持冲突**
- `push` = `git add -A && git commit && git push origin docs/<project-id>`
- 冲突时标准 git 冲突标记（`<<<<<<<` / `=======` / `>>>>>>>`）出现在文档中

## 前置配置（按顺序完成）

### 1. 创建远程仓库

在 GitHub / GitLab / 任意 git 托管平台上**手动创建一个空仓库**（不要勾选
"添加 README" 等初始化文件），例如名为 `claude-project-docs`。所有项目
的文档共用这一个仓库，通过分支区分。

### 2. 配置远程文档仓库 URL

在 GitHub / GitLab 上**手动创建一个空仓库**（不勾选 README 等初始化文
件），用于存放所有项目的 `.claude_introduction/` 文档。所有项目共用这
一个仓库，通过分支 `docs/<project-id>` 区分。

然后把仓库 URL 写入本机配置——**固定位置**：`.claude/.cache/docs-sync.conf`，
通过 `config` 子命令写入：

```bash
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh \
  config https://github.com/your-user/claude-project-docs.git
```

URL 形如 `https://github.com/用户名/仓库.git`（HTTPS）或
`git@github.com:用户名/仓库.git`（SSH），按本机 git 认证方式选择。

> `.cache/` 不随主项目 git 同步，所以换新设备第一次使用本 skill 时需
> 重新配置一次 URL（或由 Agent 主动提示你提供）。这是一次性操作。

### 3. 配置 git 用户信息（首次使用 git 的机器）

脚本需要 commit，所以 git 必须有 `user.name` 和 `user.email`。若无全局
配置，先执行（一次即可）：

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

push 时若检测到未配置会报错并给出此提示。

### 4. 配置项目标识（可选，但强烈建议）

项目标识决定远程分支名 `docs/<project-id>`，跨设备必须一致。检测优先级：

1. `.claude/settings.local.json` 中 `CLAUDE_DOCS_PROJECT_ID` — 手工覆盖
2. `.claude/project-id` 文件 — 主力，随主项目 git 跨设备自动同步
3. `git remote origin` 仓库名 — 兜底
4. git 工作目录名 — 最后手段

**推荐做法**：在 `.claude/project-id` 写入一行项目标识，并随主项目
`git commit`。这样所有设备 clone 主项目后自动带上，无需各自配置：

```bash
echo "my-app" > .claude/project-id
git add .claude/project-id
git commit -m "chore: add project-id for docs sync"
```

若想让某个项目的文档用独立标识（不跟仓库名），在 `settings.local.json`
中设 `CLAUDE_DOCS_PROJECT_ID` 覆盖即可。

### 5. 从主项目 git 跟踪中排除 `.claude_introduction/`

在主项目根目录的 `.gitignore` 中加入：

```
.claude_introduction/
```

若 `.claude_introduction/` 当前正被主项目 git 跟踪，先取消跟踪：

```bash
git rm -r --cached .claude_introduction/
echo '.claude_introduction/' >> .gitignore
git add .gitignore
git commit -m "chore: untrack .claude_introduction/"
```

脚本 `pull`/`push` 时会检测此项并给出提示，但不会自动修改主项目 git
配置。

## 操作说明

### config — 配置文档仓库 URL（首次使用或换设备时）

```bash
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh config https://github.com/your-user/claude-project-docs.git
```

把 URL 写入 `.claude/.cache/docs-sync.conf`。`pull`/`push`/`status` 会自
动从这里读取。换设备后第一次使用需要运行一次。

### pull — 拉取文档到本地

```bash
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh pull
```

- 本地空 + 远程有分支：自动初始化 git 仓库并检出分支
- 本地已是 git 仓库：标准 `git pull --no-rebase` 合并
- 远程无分支：提示先在其他设备 push
- 本地有内容但不是 git 仓库：**拒绝自动覆盖**，给出手动合并步骤（避免
  数据丢失）

### push — 推送本地文档到远程

```bash
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh push
```

- 本地有内容但非 git 仓库：自动初始化、纳入版本管理、推送
- 已是 git 仓库：检测变更（含未跟踪文件），无变更则不创建空提交
- 远程有更新未合并：push 被拒，提示先 pull

### status — 查看文档仓库状态

```bash
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh status
```

显示当前分支、远程地址、未提交变更、领先/落后远程的提交数、最近 5 条
提交。

## 冲突处理

当两端同时修改同一文档并 push，后 push 的一端会被拒绝，需先 `pull`。
`pull` 检测到内容冲突时会中止合并，并在文档中留下标准冲突标记：

```
<<<<<<< HEAD
本地修改的内容
=======
远程修改的内容
>>>>>>> origin/docs/<project-id>
```

按以下步骤解决：

```bash
cd .claude_introduction
# 1. 编辑冲突文件，删除 <<<<<<< / ======= / >>>>>>> 标记，保留正确内容
# 2. 标记已解决
git add -A
# 3. 完成合并提交
git commit -m "merge: 解决 docs 冲突"
# 4. 推送合并结果
cd ..
bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh push
```

如需放弃本次合并：

```bash
cd .claude_introduction && git merge --abort
```

## Agent 职责（使用本 skill 时主动判断）

当用户说"同步文档 / 推送文档 / 拉取文档"或调用本 skill 时，Agent 应：

1. **先跑 `status`** 检查当前配置与仓库状态：
   ```bash
   bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh status
   ```
2. **若报"未配置远程文档仓库 URL"** → 主动告诉用户需要提供一个 GitHub/GitLab
   空仓库的 URL（形如 `https://github.com/用户名/仓库.git`），并解释这个
   仓库是**专门放项目文档的独立仓库**，与主项目代码仓库不是同一个。
3. **用户给出 URL 后** → 直接用 `config` 子命令写入固定位置
   `.claude/.cache/docs-sync.conf`，不需要用户自己改文件、也不需要让用户
   在两个位置之间选：
   ```bash
   bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh config <URL>
   ```
4. **配置完成后** → 按用户原始意图执行 `pull` 或 `push`，并向用户汇报结果。
5. **若 `status` 报"无法访问远程仓库"** → 检查用户是否已在 GitHub 创建空
   仓库、URL 是否拼错、本机 git 认证（SSH key / HTTPS token）是否配置好。
6. **若 `push` 报"远程有更新未合并"** → 提示用户先 `pull`，可能产生冲突
   需手动解决（见「冲突处理」）。
7. **跨设备场景**：换新设备时，`.claude/skills/...` 脚本由 `.claude/` 同步
   skill 带过来，`.claude/project-id` 随主项目 git 自动过来；但文档仓库
   URL 需重新配置一次（Agent 主动提示并接收 URL）。

Agent 不要在未确认 URL 来源时凭空写入或假设 URL；必须由用户提供。

## 注意事项

- **`.claude_introduction/` 成为独立 git 仓库**后，主项目 `.gitignore`
  应包含 `.claude_introduction/`，避免主 git 误跟踪嵌套仓库
- **`.claude/` 已有独立同步 skill**：本 skill 只处理 `.claude_introduction/`
- **分支名格式**：`docs/<project-id>`，由脚本自动确定
- **跨设备协作**：所有设备的 `.claude/project-id` 一致即可自动关联同一
  分支
- **不作为 git submodule**：不与主项目 git 耦合，可随时单独操作
- **数据安全**：脚本在"本地有内容但非 git 仓库"时拒绝自动覆盖，必须手
  动决定如何合并
- **URL 不跨设备同步**：`.cache/docs-sync.conf` 不进 git；换设备第一次
  用时需重新配置（可由 Agent 引导完成）。配置位置是固定的，只有这一个。