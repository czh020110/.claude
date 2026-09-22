# persistent coding memory

**跨会话、跨客户端的持久化编码记忆模板仓库。**

[English](README.md) | **简体中文**

[![platforms](https://img.shields.io/badge/platforms-Codex%20%7C%20ZCode%20%7C%20Claude%20Code%20%7C%20CodeBuddy%20%7C%20WorkBuddy%20%7C%20OpenCode-blue)](https://github.com/czh020110/.claude)

这是一个模板仓库（template repo），不是可运行的软件项目。它把一套统一的 Agent / Skill / 项目记忆 / 验证脚本体系**一键安装到任意开发仓库**，让每个开发仓库都获得相同的协作规则与记忆沉淀能力——Agent 换会话不再失忆，换客户端不再重新配置。

在这里维护唯一源，通过 `sync-project-config` 全局 Skill 生成并分发到 **Codex / ZCode / Claude Code / CodeBuddy / WorkBuddy / OpenCode** 六个平台。

---

## 安装到全局 Skill 并使用

本仓库根目录的 `sync-project-config/` 是**全局 Skill 安装源**，也是仓库里唯一的一份。它不作为当前项目自动加载的项目级 Skill，也不在 `.agents/skills/` 之下。

### 第一步：把 `sync-project-config` 安装到全局 Skill 目录

把仓库根目录的 `sync-project-config/` 整个目录复制到当前客户端的全局 Skill 目录：

| 客户端 | 全局 Skill 目录 |
| --- | --- |
| Codex / ZCode | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| CodeBuddy（国内版） | `~/.codebuddy/skills/` |
| WorkBuddy 国际版（`workbuddy`） | `~/.workbuddy-ai/skills/` |
| WorkBuddy 国内版（`workbuddy-cn`） | `~/.workbuddy/skills/` |
| OpenCode | `~/.agents/skills/`（原生读取，无需软链） |

也可以直接把下面这段话复制后发给 Agent，让它替你完成安装与初始化：

```text
请把当前项目根目录的 `sync-project-config` 安装到当前客户端的全局 Skill 目录，然后用它初始化当前项目。
```

同步时脚本会把真实副本装到规范位置 `~/.agents/skills/sync-project-config/`；不读 `~/.agents/skills` 的客户端，由脚本在它自己的 Skill 目录里建**软链**指回规范副本，磁盘上永远只有一份。

### 第二步：在开发仓库里执行同步

进入需要初始化或更新的**开发仓库**根目录，由 Agent 判断客户端后调用：

```bash
bash sync-project-config/scripts/sync.sh codex
bash sync-project-config/scripts/sync.sh zcode
bash sync-project-config/scripts/sync.sh claude
bash sync-project-config/scripts/sync.sh codebuddy
bash sync-project-config/scripts/sync.sh workbuddy
bash sync-project-config/scripts/sync.sh workbuddy-cn
bash sync-project-config/scripts/sync.sh opencode
```

参数非法时会打印用法并以退出码 2 结束。

> `codebuddy`、`workbuddy` 与 `workbuddy-cn` 是不同目标：CodeBuddy 用 `~/.codebuddy/skills`，`workbuddy` 用 `~/.workbuddy-ai/skills`（国际版），`workbuddy-cn` 用 `~/.workbuddy/skills`（国内版）。装错目录不会报错，而是静默失效。
>
> WorkBuddy 的 Code 模式**只从全局目录加载 Skill**，所以两个 WorkBuddy 目标都只安装全局 Skill 并建立对应版本的软链，**不生成**项目级 `agents/` 与 `skills/`。

### 第三步：确认结果

脚本会打印 `[1/7]` ~ `[7/7]` 分阶段日志，逐条列出同步/新增的文件。完成后目标仓库应当出现：

- 对应平台的 `agents/` 与 `skills/` 目录
- `AGENTS.md`（Claude 平台额外生成 `CLAUDE.md`）
- `.project-memory/` 与 `.project-script/` 模板
- `.gitignore` 中补充的忽略项

---

## 它解决什么问题

| 问题 | 本仓库的做法 |
| --- | --- |
| 多个 AI 客户端（Codex / Claude Code / ZCode / CodeBuddy / WorkBuddy / OpenCode）各有一套配置目录，同一份提示词要复制粘贴维护 N 遍 | 只维护一份源（`.codex/agents/` + `.agents/skills/`），其余平台目录全部由脚本生成 |
| Agent 一换会话就失忆，项目背景、约束、坑要反复讲 | `.project-memory/` 索引 + 分块正文的记忆体系，配合 `read-index-memory` / `update-memory` 形成沉淀闭环 |
| 换机器后配置丢失 | 配置源在远程 Git 仓库；脚本每次启动先自更新 |
| 改完代码没有验证习惯 | `post-verify` Skill 强制收口，`.project-script/` 沉淀可复用验证脚本 |
| 项目记忆想跨设备/跨仓库同步 | `sync-project-memory` 用独立 Git 仓库的 `docs/<slug>` 分支同步 |

---

## 核心设计：唯一源与生成产物

```
唯一源（手写，只此一份）              生成产物（脚本产出，不要手动改）
─────────────────────────────        ──────────────────────────────────
.codex/agents/*.toml          ──┐      .zcode/agents/*.md
  └ developer_instructions      ├──→    .claude/agents/*.md
    是唯一提示词正文                                             │      .codebuddy/agents/*.md
                                │      .opencode/agents/*.md
                                │
.agents/skills/<name>/SKILL.md ─┼──→    .claude/skills/<name>/
  └ scripts/ references/         │      .codebuddy/skills/<name>/
                                 │      .opencode/skills/<name>/
                                 │      .agents/skills/<name>/（zcode 与 workbuddy
                                 │      通过软链复用全局副本）
AGENTS.md                      ─┴──→    CLAUDE.md（claude 平台派生）
```

三条铁律：

1. **源只维护一份**：Agent 正文写在 `.codex/agents/*.toml` 的 `developer_instructions` 里；Skill 正文写在 `.agents/skills/<name>/SKILL.md`。
2. **生成目录不是源**：`.claude/`、`.zcode/`、`.codebuddy/`、`.opencode/` 是同步产物，**绝不反向同步**。改了它们下次同步就会被覆盖。
3. **只适配元数据，不改正文**：生成时只调整 YAML frontmatter、文件名（`_` → `-`）、工具权限和平台目录，提示词正文原样保留。

---

## 目录结构

```
persistent-coding-memory/
├── AGENTS.md                      # 统一主提示词（项目规则总入口）
├── sync-project-config/           # ★ 全局 Skill 安装源（分发入口）
│   ├── SKILL.md
│   └── scripts/sync.sh            # 同步主脚本
├── .codex/                        # Codex 平台源
│   ├── config.toml                # Codex 项目级配置（并发、feature 开关）
│   ├── rules/default.rules        # 命令前缀放行规则
│   └── agents/*.toml              # ★ Agent 唯一源（3 个）
├── .agents/
│   └── skills/                    # ★ Skill 唯一源（8 个）
│       ├── <skill>/SKILL.md
│       ├── <skill>/scripts/
│       ├── <skill>/references/
│       └── <skill>/agents/openai.yaml   # Codex UI 展示元数据，不分发到其他平台
├── .project-memory/               # 项目记忆模板（8 主题 + TODO）
│   ├── {Commands,Environment,Documents,Target,Design,Boundary,Tools,Pitfalls}/MEMORY.md
│   └── TODO/{STEP.md,TODO.md,Pending.md}
├── .project-script/MEMORY.md      # 验证脚本索引模板
└── .gitignore
```

---

## 平台支持矩阵

| 平台参数 | Agent 产物 | Skill 产物 | 额外行为 |
| --- | --- | --- | --- |
| `codex` | 直接同步 `.codex/` 源目录 | 直接同步 `.agents/skills/` 源目录 | 同步 `.codex/config.toml`、`.codex/rules/` |
| `zcode` | `.codex/agents/*.toml` → `.zcode/agents/*.md` | 复用 `.agents/skills/` | AGENTS.md 工具名适配；额外拷贝全局 Skill 到 `~/.zcode/skills/` |
| `claude` | → `.claude/agents/*.md` | → `.claude/skills/` | 由 `AGENTS.md` 派生根目录 `CLAUDE.md` |
| `codebuddy` | → `.codebuddy/agents/*.md` | → `.codebuddy/skills/` | 使用全局 MCP 配置流程 |
| `workbuddy` | 无（仅全局） | 无（仅全局） | 安装全局 Skill 并软链到 `~/.workbuddy-ai/skills`（国际版） |
| `workbuddy-cn` | 无（仅全局） | 无（仅全局） | 安装全局 Skill 并软链到 `~/.workbuddy/skills`（国内版） |
| `opencode` | → `.opencode/agents/*.md` | → `.opencode/skills/` | 将 `AGENTS.md` 工具名适配为 `todowrite` / `question`；直接复用规范全局副本（OpenCode 原生读 `~/.agents/skills/`，不建软链） |

### 生成时的适配规则

**Agent（`.toml` → `.md`）**

- 文件名：`code_review_custom` → `code-review-custom`（下划线转连字符）
- frontmatter 生成 `name` + `description`（description 用 JSON 转义，兼容中文与特殊字符）
- 模型/工具按平台注入：
  - Claude：`code_review_custom` → `sonnet`，`docs_research` → `haiku`
  - ZCode：统一 `model: glm-5.3-flash`
  - CodeBuddy：按表注入 `tools` / `disallowedTools`（如审查类 Agent 只读、禁写）
- 正文 = TOML 中 `developer_instructions` 的内容，**原样保留**
- OpenCode：不输出 `name:`（文件名即 agent 名，未知 frontmatter 会被忽略），补 `mode: subagent`，限制用 `permission` 而非 `tools`（如审查 agent 为 `edit: deny`）

**Skill**

- 复制 `SKILL.md` + `scripts/` + `references/`
- 排除 `**/agents/*.yaml`（Codex UI 专用）
- Claude / CodeBuddy：frontmatter 缺失 `user-invocable:` 时自动补 `user-invocable: true`
- `sync-project-memory/scripts/sync-memory.sh` 在 Claude / CodeBuddy 下会把内部路径 `.agents/.cache` 改写成 `.claude/.cache` / `.codebuddy/.cache`

**AGENTS.md / CLAUDE.md**

- 以源码仓库的 `AGENTS.md` 为准，**保留目标项目 `<!-- sync-project-config:custom-prompts -->` 标记以下的自定义内容**（标记以上整体替换）
- 同步后的受控区工具名按平台改写：

  | 源写法 | Claude Code | ZCode | CodeBuddy / WorkBuddy | OpenCode |
  | --- | --- | --- | --- | --- |
  | `update_plan` | `TodoWrite` | `TodoWrite` | `TodoWrite` | `todowrite` |
  | `request_user_input` | `AskUserQuestion` | `AskUserQuestion` | `AskUserQuestion` | `question` |

  Claude Code 的 `TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet` 是另一套任务系统；这里的提示词统一使用 `TodoWrite`。ZCode 还可以使用只读的 `TodoRead`，WorkBuddy 的实现类名虽然是 `TodoWriteTool`，但提示词面向的工具名是 `TodoWrite`。OpenCode 使用小写内置工具 `todowrite` 和 `question`，并提供只读的 `todoread` 作为 todo 对应工具。

- 若 `AGENTS.md` 中不存在该标记，脚本不会做任何切分，整个文件会被覆盖。因此 `sync-project-config` Skill 会要求 Agent 先停下、不执行脚本：先比对本地 `AGENTS.md` 与上游 `AGENTS.md`，定位受控区与自定义区的边界，向用户确认后在该处插入标记，然后再执行同步。脚本不再识别任何旧版标题——用旧模板同步过的项目需要手动补一次标记。

---

## sync.sh 执行流程

脚本每次启动会**先自更新**：克隆远程模板仓库 → 覆盖当前项目根目录的 `sync-project-config/` → `exec` 重新执行最新脚本 → 再走完剩余步骤。因此即使全局装的是旧版本，也能先升级再执行最新逻辑。

| 阶段 | 动作 | 覆盖策略 |
| --- | --- | --- |
| bootstrap | 克隆远程源，覆盖本地 `sync-project-config/` | 全覆盖 |
| global skill | 安装/刷新全局 Skill 目录 | 先删后拷 |
| `[1/7]` | 使用已更新的远程配置源 | — |
| `[2/7]` | 同步 `AGENTS.md`（+ `CLAUDE.md`）与全局 Skill | 标记以上替换，以下保留 |
| `[3/7]` | 生成平台 Agent / Skill | 全覆盖生成 |
| `[4/7]` | 同步 `.project-memory/` 模板 | **只新增缺失文件，不覆盖已有** |
| `[5/7]` | 同步 `.project-script/` 模板 | **只新增缺失文件，不覆盖已有** |
| `[6/7]` | 检查并补全 `.gitignore` | 只追加缺失条目 |
| `[7/7]` | 完成 | — |

三种复制语义，决定了"哪些会被覆盖、哪些不会"：

| 函数 | 语义 | 排除项 |
| --- | --- | --- |
| `copy_tree` | 目标文件与源不一致就覆盖 | `.cache/*`、`settings.local.json`、`*.local.json`、`*.secret*`、`*.key`、`.DS_Store`、`CODEBUDDY.local.md` |
| `copy_missing_tree` | 目标已存在就跳过 | `.DS_Store` |
| `copy_skill_tree` | 覆盖，但对 `SKILL.md` 和记忆同步脚本做平台适配 | `**/agents/*.yaml`、`.DS_Store` |

> **关键结论**：你的项目记忆正文（`.project-memory/`）和验证脚本（`.project-script/`）**永远不会被同步覆盖**，只会补齐缺失的模板文件。可以放心在目标项目里长期积累。

---

## 环境变量

| 变量 | 作用 | 默认值 |
| --- | --- | --- |
| `PROJECT_CONFIG_REPO_URL` | 模板仓库地址（最高优先级） | `https://github.com/czh020110/.claude.git` |
| `CODEX_CONFIG_REPO_URL` | Codex/ZCode/Claude 的模板仓库地址 | 同上 |
| `CODEBUDDY_CONFIG_REPO_URL` | CodeBuddy/WorkBuddy 的模板仓库地址 | 同上 |
| `CODEX_GLOBAL_SKILL_DIR` | **规范目录**——唯一的真实副本在这里 | `~/.agents/skills` |
| `CLAUDE_GLOBAL_SKILL_DIR` | Claude 软链目标 | `~/.claude/skills` |
| `CODEBUDDY_GLOBAL_SKILL_DIR` | CodeBuddy 软链目标 | `~/.codebuddy/skills` |
| `WORKBUDDY_GLOBAL_SKILL_DIR` | 覆盖当前 WorkBuddy 版本的全局 Skill 目录 | `workbuddy` 为 `~/.workbuddy-ai/skills`；`workbuddy-cn` 为 `~/.workbuddy/skills` |
| `WORKBUDDY_SKILL_LINK_DIRS` | 可选的 WorkBuddy 软链目标，冒号分隔 | 只链接当前选择的版本目录 |
| `OPENCODE_GLOBAL_SKILL_DIR` | OpenCode Skill 目录（默认就是规范目录） | `~/.agents/skills` |

> 客户端配置目录不是默认路径时覆盖对应变量即可，无需改脚本。软链目标只会被建软链；若该位置已是真实目录，脚本会跳过并提示，不会删除。

内部变量 `SYNC_PROJECT_CONFIG_BOOTSTRAPPED` / `SYNC_PROJECT_CONFIG_REMOTE_DIR` 用于自更新的二次执行，不需要手动设置。若自行设置 `SYNC_PROJECT_CONFIG_REMOTE_DIR`，**只能指向可丢弃的临时检出**——脚本退出时会删除该目录。

### Context7 MCP

仓库不再保存项目级 Context7 MCP 配置。`sync-project-config` Skill 会要求 Agent 先检查当前客户端的全局 MCP 配置，已有 `context7` 就直接复用，缺失时只配置到客户端全局，不回退到项目级 MCP 配置。

---

## 内置 Agent 清单

源文件在 `.codex/agents/`，各平台产物为同名连字符 `.md`。

| Agent | 职责 | 调用时机 |
| --- | --- | --- |
| `code_review_custom` | 审查指定范围的代码变更，判断正确性与风险，输出 P0–P3 分级结论 | 用户明确给出审查范围时（由 `code-review-custom` Skill 委托） |
| `collect_update_memory` | 全量记忆同步：按 commit / 增量 / 本地变更顺序收敛事实 | 用户主动要求阶段性或全量同步记忆时（由 `collect-update-memory` Skill 委托） |
| `docs_research` | 纯外部技术文档查询助手，不读本地代码 | 需同时核实 3 个以上外部库/接口时（由 `docs-research` Skill 委托） |

---

## 内置 Skill 清单

项目级 Skill 源文件在 `.agents/skills/`（共 8 个）。全局分发入口 `sync-project-config` **不在其中**——它在仓库根目录，需要单独安装（见[安装到全局 Skill 并使用](#安装到全局-skill-并使用)）。

| Skill | 作用 | 触发条件 |
| --- | --- | --- |
| `read-index-memory` | 读取 `.project-memory/` 各主题索引，按需路由到正文 | **每个新任务开始时** |
| `update-memory` | 把已实施且可验证的局部事实写入对应主题 | 本轮确认了有效事实/约束/偏好/经验 |
| `collect-update-memory` | 全量记忆同步编排（委托 `collect_update_memory`） | 用户主动要求阶段性/全量同步 |
| `sync-project-memory` | 把 `.project-memory/` 推拉到远程记忆仓库 | 用户要求 push / pull / 查看同步状态 |
| `post-verify` | 修改类任务收口验证，管理验证脚本与索引 | **所有修改类任务交付前，强制执行** |
| `git-commit` | 按规范分组、生成结构化 commit message 并提交 | 用户明确要求提交/保存更改 |
| `code-review-custom` | 确定审查范围并委托审查 Agent | 用户明确给出审查范围 |
| `docs-research` | 组织批量文档查询问题并委托查询 Agent | 需同时核实 3+ 外部接口或复杂版本迁移 |

### 一个典型任务的执行链路

```
新任务开始
  └─ read-index-memory          读索引，按需读正文
       ↓
  （实施修改：编码 / 配置 / 文档）
       ↓
   post-verify                  验证、修复循环、沉淀验证脚本到 .project-script/
       ↓
   update-memory                把本轮确认的事实写入 .project-memory/
       ↓
  （用户要求时）git-commit → collect-update-memory → sync-project-memory
```

---

## 项目记忆体系

### 结构：索引 + 分块正文

```
.project-memory/
├── Commands/MEMORY.md      ← 只有索引行，不含正文
├── Commands/<主题>.md      ← 事实正文
├── Environment/
├── Documents/
├── Target/
├── Design/
├── Boundary/
├── Tools/
├── Pitfalls/
└── TODO/{STEP.md, TODO.md, Pending.md}
```

| 主题 | 记什么 |
| --- | --- |
| `Commands` | 安装、运行、构建、测试、评估、部署、故障恢复 |
| `Environment` | 工具/版本、硬件、路径、环境变量、外部服务、平台限制 |
| `Documents` | 用户维护的项目文档（正文默认只读） |
| `Target` | 已生效的项目目的、范围、验收标准 |
| `Design` | 当前架构、模块职责、协作方式与设计理由 |
| `Boundary` | 必须保持的行为、范围外事项、限制、质量底线 |
| `Tools` | 可复用的辅助脚本、可视化、统计、数据转换工具 |
| `Pitfalls` | 可复用的执行经验：适用场景、识别信号、根因、规避方式 |

规则：同一事实只保留一个权威归属；正文存在就必须有索引，索引不能指向不存在的文件；结构变化（新建/删除/重命名/拆分/合并）必须与索引同轮完成。

### 三份 TODO 的分工

| 文件 | 谁维护 | 记什么 |
| --- | --- | --- |
| `TODO/TODO.md` | **用户** | 普通待办；只有用户明确要求时主模型才写 |
| `TODO/Pending.md` | 主模型 | 尚未实施的方案/设计/决策，须含背景、待确认决策、完成条件、关联范围 |
| `TODO/STEP.md` | 主模型 | 长期阶段拆分（临时任务不写） |

复选框格式统一：`[ ]` 未开始，`[-]` 处理中，`[x]` 已完成。

**关键分流**：Pending 里的未实施方案**不是事实**，不得写入任何记忆正文。方案落地并验证后，移除 Pending 条目，再把最终真实状态写入对应主题。方案被否决则只移除条目。

---

## 远程记忆同步

`sync-project-memory` 把 `.project-memory/` 当作一个**独立 Git 仓库**同步到远程，实现跨设备记忆延续。

入口（路径随平台不同，以实际生成的 Skill 目录为准）：

```bash
# Codex / ZCode
bash .agents/skills/sync-project-memory/scripts/sync-memory.sh <子命令>

# Claude
bash .claude/skills/sync-project-memory/scripts/sync-memory.sh <子命令>

# CodeBuddy
bash .codebuddy/skills/sync-project-memory/scripts/sync-memory.sh <子命令>

# OpenCode
bash .opencode/skills/sync-project-memory/scripts/sync-memory.sh <子命令>

```

| 子命令 | 作用 |
| --- | --- |
| `pull` | 拉取并合并远程记忆到本地 |
| `push` | 推送本地记忆到远程 |
| `info` | 查看状态（不做可达性预检，永远 0 退出） |
| `status` | 查看详细状态 |
| `config <URL>` | 配置远程记忆仓库地址 |
| `diagnose` | 只输出摘要，不做网络预检 |

**项目标识**：由主代码仓库 `git remote get-url origin` 的 URL 唯一映射为 `docs/<slug>` 分支名。同一个代码仓库在远程记忆仓库里始终对应同一个分支，换设备无需额外配置。主仓库未配置 `origin` 时脚本直接报错，不回退到本地目录名。

**记忆仓库地址**保存在 `.agents/.cache/docs-sync.conf`（一行纯文本，**不进 Git**），因此跨设备需要各配一次：

```bash
... sync-memory.sh config https://github.com/<you>/<your-project-docs>.git
```

首次使用时若 `.project-memory/` 已有文件但还不是 Git 仓库，脚本会自动纳入版本管理并合并。推送前会做远程可达性预检；合并冲突会中止并在文件中留下冲突标记，手动解决后重新 `push`，或用 `cd .project-memory && git merge --abort` 放弃。

---

## 验证脚本目录

`.project-script/` 存放**可复用的验证脚本**，由 `post-verify` Skill 管理：

- 脚本按类型放在 `.project-script/<验证类型>/` 下，不要堆在根目录
- `.project-script/MEMORY.md` 只记录路径、用途、适用场景、入口命令和前置条件，**不复制脚本正文**
- 新增/删除/移动/重命名脚本时，必须同轮同步索引
- 脚本只能通过环境变量读取凭证，不得保存 API key / token / Cookie

修改类任务（含配置、模板、文档、提示词同步）在交付前都必须执行 `post-verify`；纯咨询、审查、调研不需要。

---

## .gitignore 处理

脚本会按平台追加缺失的忽略项，已有内容不会被删除。

**CodeBuddy：**

```
.project-memory/
.project-script/
.codebuddy/settings.local.json
.codebuddy/CODEBUDDY.local.md
.codebuddy/.cache/
```

**WorkBuddy：**

```
.project-memory/
.project-script/
```

**OpenCode：**

```
.project-memory/
.project-script/
.opencode/
```

**其他平台：**

```
.codex/
.zcode/
.claude/
.agents/
.project-memory/
.project-script/
AGENTS.md
CLAUDE.md
```

> 注意：CodeBuddy / WorkBuddy 之外的平台默认把 `AGENTS.md` 和 `CLAUDE.md` 也忽略掉——它们是同步产物，不需要进版本库。如果你的项目希望把 `AGENTS.md` 提交进仓库，同步后手动从 `.gitignore` 移除该行即可。

---

## 边界与安全

脚本**不会**做的事：

- 不覆盖目标项目标记以下的自定义区；根 `AGENTS.md` 的受控区由源码刷新，并按平台为 Claude Code、ZCode、CodeBuddy、WorkBuddy、OpenCode 适配工具名；派生的 `CLAUDE.md` 使用同一套 Claude 映射。
- 不把生成目录当源，不从 `.claude/`、`.zcode/`、`.codebuddy/`、`.opencode/` 反向同步
- 不覆盖目标项目已有的 `.project-memory/` 与 `.project-script/` 内容
- 不复制凭证、本地缓存、`settings.local.json`、`CODEBUDDY.local.md`、Codex UI 专用的 `agents/openai.yaml`
- 用户未明确要求同步时不调用本 Skill

记忆写入**不会**做的事：

- 不写密码、token、私钥、Cookie
- 不写未实施方案、待定决策、候选方案、修改日志
- 不记录单次工具报错、偶发环境故障、原始调试日志

---

## 维护者指南

### 新增一个 Skill

1. 在 `.agents/skills/<name>/SKILL.md` 写正文，frontmatter 至少含 `name` 和 `description`
2. 需要脚本放 `scripts/`，需要长参考文档放 `references/`
3. 纯 Codex UI 展示需求才加 `agents/openai.yaml`（不会分发到其他平台）
4. 在目标仓库重新跑一次 `sync.sh <platform>` 即可分发

### 新增一个 Agent

1. 在 `.codex/agents/<name>.toml` 新建，正文写在 `developer_instructions = """..."""` 里
2. 必须含 `name` 和 `description` 字段，否则生成脚本会报错退出
3. 如需为 Claude / CodeBuddy 指定模型或工具权限，在 `sync.sh` 的 `claude_models` / `codebuddy_tools` 映射表里加一行；OpenCode 则加到 `opencode_permissions`（它用 `permission` 而非 `tools` 做限制）
4. 重新跑 `sync.sh` 生成各平台产物

### 修改提示词

**只改源，不要改生成目录。** 改完 `.codex/agents/*.toml` 或 `.agents/skills/*/SKILL.md` 后，提交并推送到模板仓库，各开发仓库下次执行 `sync.sh` 时会自动拉取最新版本（脚本启动时先自更新）。

### 修改 `AGENTS.md`

`<!-- sync-project-config:custom-prompts -->` 标记**以上**是受控区（会被远程版本替换），**以下**是各项目的自定义区（会被保留）。公共规则改标记以上的部分。

---

## 常见问题

**Q：同步会不会冲掉我在项目里积累的记忆？**

不会。`.project-memory/` 和 `.project-script/` 用的是"只新增缺失"策略，已有文件一律跳过。只有 Agent/Skill 生成目录和 `AGENTS.md` 标记以上会被覆盖。

**Q：为什么脚本第一次运行要联网克隆仓库？**

这是自更新机制：先用远程最新版本覆盖项目根目录的 `sync-project-config/`，再 `exec` 执行新脚本。好处是全局安装的旧版本也能立刻获得最新逻辑；代价是离线环境无法直接运行。离线场景需要本地已有一份模板仓库检出，然后同时指定两个内部变量跳过克隆：

```bash
SYNC_PROJECT_CONFIG_BOOTSTRAPPED=1 \
SYNC_PROJECT_CONFIG_REMOTE_DIR=/path/to/local/template-checkout \
  bash sync-project-config/scripts/sync.sh codex
```

**Q：想用自己 fork 的模板仓库怎么办？**

设置 `PROJECT_CONFIG_REPO_URL`（或对应平台的 `CODEX_CONFIG_REPO_URL` / `CODEBUDDY_CONFIG_REPO_URL`）指向你的仓库地址。

**Q：该用 `codebuddy`、`workbuddy` 还是 `workbuddy-cn`？**

国内版 CodeBuddy 用 `codebuddy`，WorkBuddy 国际版用 `workbuddy`，WorkBuddy 国内版用 `workbuddy-cn`。快速判断：`~/.workbuddy-ai/` 对应 `workbuddy`，`~/.workbuddy/` 对应 `workbuddy-cn`，`~/.codebuddy/` 对应 `codebuddy`。三者写到不同目录，选错不会报错，而是静默失效。

**Q：WorkBuddy 会加载放在项目里的 Skill 吗？**

不会。WorkBuddy 的 Code 模式只从全局 Skill 目录加载，因此 `workbuddy` 和 `workbuddy-cn` 都不生成项目级 `agents/` 与 `skills/`。全局的 `sync-project-config` 以真实目录装在 `~/.agents/skills/` 下，再软链到当前选择的 WorkBuddy 目录。所以 `.agents/skills/` 下那 8 个项目 Skill 在 WorkBuddy 下按设计不可用，只有分发入口可用。

**Q：我的客户端全局 Skill 目录不是默认值？**

覆盖对应变量即可——`CODEBUDDY_GLOBAL_SKILL_DIR`、`WORKBUDDY_GLOBAL_SKILL_DIR` 或 `WORKBUDDY_SKILL_LINK_DIRS`（冒号分隔）。这些是软链目标，真实副本始终留在 `CODEX_GLOBAL_SKILL_DIR`。

**Q：`sync-memory.sh` 报 `Remote memory repository URL is not configured`？**

先在 GitHub/GitLab 建一个专门存放项目记忆的空仓库（**不要**用主项目仓库），再执行 `sync-memory.sh config <URL>`。

**Q：换设备后记忆同步要重新配置吗？**

Agent/Skill 随平台配置同步，无需处理；项目标识来自主仓库 `origin` remote，也无需处理；只有远程记忆仓库 URL 存在本地缓存里，需要重新 `config` 一次。

**Q：OpenCode 为什么不需要软链？**

OpenCode 除了 `~/.config/opencode/skills/` 和 Claude 兼容的 `~/.claude/skills/`，**原生就会搜索 `~/.agents/skills/<name>/SKILL.md`**。规范副本正好就在 `~/.agents/skills/`，所以直接被读到。刻意不往 `~/.config/opencode/skills/` 建软链：OpenCode 要求各位置 skill 名唯一，同一个名字出现两份会冲突。项目级副本放在 `.opencode/skills/`。

**Q：MCP 配置在哪里？**

同步脚本不会生成或复制项目级 MCP 配置文件。`sync-project-config` Skill 会要求 Agent 复用当前客户端已有的全局 `context7` 配置，缺失时只配置到客户端全局。
