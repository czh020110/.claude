# Claude Code 模板工程维护

## 当前任务

当前仓库不是业务项目本体，而是在维护 `claude-copy/` 这套可复制到新项目的 `.claude/` 大项目开发模板。

本阶段主要修改目标：优化 `claude-copy/` 的 Claude Code 上下文、规则、项目事实目录和文档更新 skill，使新项目复制后能支持 agent 长期、可追踪、可验收地开发。

## 当前模板结构

- `claude-copy/CLAUDE-COPY.md`：复制到新项目后作为 `.claude/CLAUDE.md` 使用，负责导入关键项目事实和给模型执行上下文。
- `claude-copy/rules/`：自动加载的长期规则，只放稳定行为约束。
  - `代码更新.md`
  - `接口规范.md`
  - `文档查询.md`
  - `注释说明.md`
- `claude-copy/introduction/`：项目事实目录，具体文件默认可为空，只记录真实项目内容。
  - `项目具体说明/01-项目概览.md`：用户维护，只读项目介绍。
  - `项目实现目标/01-目标边界.md`
  - `项目实现目标/02-模块规划.md`
  - `环境说明/01-本地开发环境.md`
  - `环境说明/02-常用命令.md`
  - `数据流/01-核心数据流.md`
  - `TODO/STEP.md`：长期项目大方向。
  - `TODO/TODO.md`：下一次提交可完成的细粒度 TODO。
  - `TODO/DONE.md`：上一次 TODO.md 中已验收完成的事项。
  - `修改记录/`：按 git commit description 命名的一次提交维度修改记录。
- `claude-copy/skills/update-docs/`：文档更新 skill，负责更新项目文档、TODO/DONE、修改记录，并可根据用户要求提交 git commit。
  - `SKILL.md`：所有文档格式和更新流程直接写在这里。
  - `scripts/rotate_todo.py`：把旧 TODO.md 自动迁移到 DONE.md，并写入下一次细粒度 TODO。
- `claude-copy/settings.example.json`：新项目权限配置示例。

## 维护原则

- 不要把 `claude-copy/introduction/` 写成模板说明；这里的具体文件只承载新项目真实事实。
- 文档格式、生成规则、TODO/DONE 轮转规则应放在 `claude-copy/skills/update-docs/SKILL.md`。
- `项目概览.md` 是用户维护的项目介绍，模型只读，不通过 skill 更新。
- 修改记录按一次 git commit 维度生成，不按文件分别写。
- 修改记录要详细解释修改原因、修改前后、关键函数/接口/文档项、影响和验证结果，但不能复制 diff 或大段源码。
- 细粒度 TODO 轮转必须使用 `scripts/rotate_todo.py`，不要手动搬运 TODO/DONE。
- 删除旧项目绑定内容，但保留可复用的强规则和流程。

## 验证要求

修改模板后至少检查：

- `claude-copy/introduction/` 下没有 `00-如何填写.md`、`template.md`、`00-生成规则.md`。
- `claude-copy/introduction/` 下具体事实文件不包含填写教程或示例模板。
- `claude-copy/skills/update-docs/SKILL.md` 包含 TODO、DONE、修改记录、数据流等固定格式。
- `scripts/rotate_todo.py` 在临时目录中可正常迁移旧 TODO 并写入新 TODO。
- 旧项目专属词不应残留。
