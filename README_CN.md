# Morrowmark

**面向 Codex、ZCode、Claude Code、CodeBuddy、WorkBuddy 和 OpenCode 的项目记忆与编码 Agent 工作流。**

[English](README.md) | **简体中文**

[![platforms](https://img.shields.io/badge/platforms-Codex%20%7C%20ZCode%20%7C%20Claude%20Code%20%7C%20CodeBuddy%20%7C%20WorkBuddy%20%7C%20OpenCode-blue)](https://github.com/czh020110/.claude)

**让项目记得住，也让 Agent 接得上。**

Morrowmark 为每个仓库维护长期的项目上下文：把已确认的当前事实与已确定的预期设计分开，并让 Agent 按任务读取相关主题。配套的 skills 和 subagents 将计划、文档查询、验证和记忆更新等工作流程带到六种编码客户端。记忆保存在项目仓库中，不写入客户端的全局记忆。

## 记忆记录什么

- **项目事实：** 项目目的与范围（`Target`）、当前实现（`Design`）、必须遵守的边界与项目偏好（`Boundary`、`Preferences`）。
- **工作知识：** 命令、环境、项目文档、可复用工具和反复出现的问题经验（`Commands`、`Environment`、`Documents`、`Tools`、`Pitfalls`）。
- **未来设计：** 已确定但尚未实现的设计（`Plan/`）。`TODO/TODO.md` 则由用户维护。

## 任务流程

1. 先读各主题索引和 TODO，再按需读取相关记忆正文。
2. 执行用户要求的项目工作。
3. 每次修改交付前都必须运行 `post-verify`。
4. 验证通过后，使用 `update-memory` 仅记录已确认、可复用的事实；不记录未验证说法或临时任务进度。

## 快速开始

1. 将本仓库的 `sync-morrowmark/` 安装到当前客户端的全局 Skill 目录：

   | 客户端 | 全局 Skill 目录 |
   | --- | --- |
   | Codex、ZCode、OpenCode | `~/.agents/skills/` |
   | Claude Code | `~/.claude/skills/` |
   | CodeBuddy | `~/.codebuddy/skills/` |
   | WorkBuddy 国际版 | `~/.workbuddy-ai/skills/` |
   | WorkBuddy 国内版 | `~/.workbuddy/skills/` |

首次同步前，请用这个新名称替换之前安装的全局版本。

   也可以把下面这段提示词复制给 Agent：

   ```text
   请从 https://github.com/czh020110/.claude/tree/main/sync-morrowmark 安装 `sync-morrowmark` Skill 到当前客户端的全局 Skill 目录。该链接中的仓库仅作为 Skill 来源，当前会话打开的仓库才是目标项目。安装完成后，先询问我是否要立即初始化或更新该仓库；得到确认前不要执行同步。
   ```

2. 首次同步时运行刚安装的全局脚本；它会在目标仓库创建项目副本。后续更新时，在目标仓库根目录运行：

   ```bash
   bash sync-morrowmark/scripts/sync.sh codex
   ```

   根据客户端将 `codex` 替换为 `zcode`、`claude`、`codebuddy`、`workbuddy`、`workbuddy-cn` 或 `opencode`。

同步会生成对应平台的 Agent、Skill 配置并补齐项目记忆模板；会保留现有自定义提示词、累积的记忆正文，以及平台支持的同名 Agent 思考程度设置。

## 项目记忆

记忆保存在 `.project-memory/`，采用“索引 + 正文”的结构。每个主题的 `MEMORY.md` 都是索引，事实保存在单独的主题正文中。

`Design` 描述代码当前的实际情况；`Plan/` 保存项目已确定、准备实现的设计。`TODO/TODO.md` 由用户维护。

## Skills

### 用户主动调用

| Skill | 用途 |
| --- | --- |
| `sync-morrowmark` | 安装或更新项目 Agent、Skill 和模板。 |
| `draft-long-term-plan` | 创建或扩展 `Plan/` 中的项目预期设计。 |
| `collect-update-memory` | 根据一段提交和本地改动整理项目记忆。 |
| `sync-project-memory` | 通过独立远程仓库推送或拉取项目记忆。 |
| `git-commit` | 按修改目的分组并创建提交；需用户提出。 |
| `handoff` | 生成可复制到新会话的精简任务交接提示词。 |

### Agent 按流程使用

| Skill | 用途 |
| --- | --- |
| `read-index-memory` | 在任务开始时读取记忆索引，并定位相关正文。 |
| `design-alignment` | 与用户确定设计变更或冲突，并记录确认后的设计。 |
| `docs-research` | 查询多个或较复杂的外部技术文档问题。 |
| `post-verify` | 改动完成后执行最终检查。 |
| `update-memory` | 验证通过后记录已确认的事实。 |

## Subagents

- `collect_update_memory`：检查记忆主题结构并执行完整记忆同步。
- `docs_research`：查询外部技术文档，不检查本地项目代码。
