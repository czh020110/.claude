# persistent coding memory

**多平台的项目级编码记忆。**

[English](README.md) | **简体中文**

[![platforms](https://img.shields.io/badge/platforms-Codex%20%7C%20ZCode%20%7C%20Claude%20Code%20%7C%20CodeBuddy%20%7C%20WorkBuddy%20%7C%20OpenCode-blue)](https://github.com/czh020110/.claude)

这是一个模板仓库（template repo），不是可运行的软件项目。它把一套 Agent、Skill 和项目记忆体系一键安装到任意开发仓库。

**只做项目级记忆，不碰全局记忆。** 它沉淀的所有内容都留在被安装的那个仓库里——从不写入客户端的全局记忆——而且只服务于代码项目。

记忆按主题划分，一共八大主题：

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

在这里维护唯一源，通过 `sync-project-config` 全局 Skill 生成并分发到 **Codex / ZCode / Claude Code / CodeBuddy / WorkBuddy / OpenCode** 六个平台。

---

## 安装到全局 Skill 并使用

本仓库根目录的 `sync-project-config/` 是全局 Skill 安装源，也是仓库里唯一的一份。它不是项目级 Skill，也不在 `.agents/skills/` 之下。

### 第一步：把 `sync-project-config` 安装到全局 Skill 目录

把仓库根目录的 `sync-project-config/` 整个目录复制到当前客户端的全局 Skill 目录：

| 客户端 | 全局 Skill 目录 |
| --- | --- |
| Codex / ZCode | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| CodeBuddy（国内版） | `~/.codebuddy/skills/` |
| WorkBuddy 国际版（`workbuddy`） | `~/.workbuddy-ai/skills/` |
| WorkBuddy 国内版（`workbuddy-cn`） | `~/.workbuddy/skills/` |
| OpenCode | `~/.agents/skills/` |

也可以直接把下面这段话复制后发给 Agent，让它替你完成安装与初始化：

```text
请把当前项目根目录的 `sync-project-config` 安装到当前客户端的全局 Skill 目录，然后用它初始化当前项目。
```

### 第二步：在开发仓库里执行同步

进入需要初始化或更新的开发仓库根目录，按你的客户端执行对应平台：

```bash
bash sync-project-config/scripts/sync.sh codex
bash sync-project-config/scripts/sync.sh zcode
bash sync-project-config/scripts/sync.sh claude
bash sync-project-config/scripts/sync.sh codebuddy
bash sync-project-config/scripts/sync.sh workbuddy
bash sync-project-config/scripts/sync.sh workbuddy-cn
bash sync-project-config/scripts/sync.sh opencode
```

`codebuddy`、`workbuddy` 与 `workbuddy-cn` 是不同目标，写到不同目录。快速判断：`~/.codebuddy/` 对应 `codebuddy`，`~/.workbuddy-ai/` 对应 `workbuddy`，`~/.workbuddy/` 对应 `workbuddy-cn`。选错不会报错，而是静默失效。

### 第三步：确认结果

执行完成后，目标仓库里应当出现对应平台的 `agents/` 与 `skills/` 目录、`AGENTS.md`（Claude 平台额外生成 `CLAUDE.md`），以及 `.project-memory/` 与 `.project-script/` 模板。

---

## `.project-memory/`：记忆本体

`.project-memory/` 存放项目记忆。每个主题目录下的 `MEMORY.md` 只做索引，事实写在正文文件里，因此 Agent 先读索引、再按需只读正文。

```
.project-memory/
├── Commands/MEMORY.md      ← 只有索引
├── Commands/<主题>.md      ← 事实正文
├── Environment/  Documents/  Target/  Design/
├── Boundary/  Tools/  Pitfalls/
└── TODO/{TODO.md, Pending.md, STEP.md}
```

`TODO/` 下三个文件由不同的人维护：

| 文件 | 谁维护 | 记什么 |
| --- | --- | --- |
| `TODO.md` | **用户** | 你自己的待办；只有你明确要求时 Agent 才写 |
| `Pending.md` | Agent | 尚未实施的方案与决策 |
| `STEP.md` | Agent | 长期阶段拆分，用于跨阶段的任务 |

记忆不保存任何凭证；同步也不会覆盖你已经积累的记忆——只会补齐缺失的模板文件。

## `.project-script/`：可复用的验证脚本

`.project-script/` 存放验证改动用的脚本，按类型分目录，由 `.project-script/MEMORY.md` 索引（路径、用途、入口命令、前置条件）。脚本只从环境变量读取凭证，不保存密钥或 token。

---

## 一个任务是怎么跑的

`AGENTS.md` 让每个任务走同一条闭环：

1. **读记忆索引** —— `read-index-memory` 读取每个主题的 `MEMORY.md`。
2. **只读索引指向的正文** —— 由索引决定哪些相关，其余不扫描。
3. **执行修改。**
4. **记录本轮真实确认的事实** —— `update-memory` 把这一轮确立的事实写进对应主题。
5. **交付前验证** —— `post-verify` 做最终针对性检查并留下证据。

**记忆只记录当前项目的事实，不记录以后的方案设计。** 尚未实施的方案、架构和决策写进 `.project-memory/TODO/Pending.md`，你自己的待办写进 `.project-memory/TODO/TODO.md`。Agent 会按需读取这两个文件，所以停在这里的想法不会丢。

---

## Skill 清单

| Skill | 作用 | 谁调用 |
| --- | --- | --- |
| `read-index-memory` | 读取各主题索引，路由到相关正文 | Agent |
| `update-memory` | 把本轮确认的事实写入对应主题 | Agent |
| `post-verify` | 交付前的收口验证闸门 | Agent |
| `docs-research` | 批量外部文档查询，委托给 `docs_research` agent | Agent |
| `git-commit` | 创建 git commit：按目的分组、生成结构化描述、验证 | 用户 |
| `collect-update-memory` | 全量记忆同步编排，委托给 `collect_update_memory` agent | 用户 |
| `code-review-custom` | 确定审查范围，委托给 `code_review_custom` agent | 用户 |
| `sync-project-memory` | 通过独立远程仓库推拉 `.project-memory/`，实现跨设备记忆延续 | 用户 |
| `sync-project-config` | 分发入口：初始化并更新项目的 Agent、Skill 与模板 | 用户 |

## Agent 清单

| Agent | 作用 |
| --- | --- |
| `code_review_custom` | 审查指定范围的代码变更，判断正确性与风险，输出 P0–P3 分级结论 |
| `collect_update_memory` | 全量记忆同步：按 commit / 增量 / 本地变更顺序收敛已实施事实 |
| `docs_research` | 纯外部文档查询，不读本地代码 |

---

## 维护本模板

### 修改提示词

**只改源，不要改生成目录。** 改完 `.codex/agents/*.toml` 或 `.agents/skills/*/SKILL.md` 后，提交并推送到模板仓库，各开发仓库下次执行 `sync.sh` 时会自动拉取最新版本。

### 修改 `AGENTS.md`

`<!-- sync-project-config:custom-prompts -->` 标记**以上**是受控区（每次同步会被替换），**以下**是各项目自己的区域（会被保留）。公共规则改标记以上的部分。
