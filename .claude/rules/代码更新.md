# 代码更新规则

## 1. 适用范围

- 适用于项目内所有代码新增、修改、删除、重构场景。
- 适用于与代码变更直接相关的验证、进度同步和 git 提交说明整理。

---

## 2. 术语统一

- 统一使用：`git 提交说明`。
- 所有变更说明直接写入对应 git commit。
- 每个 git commit 都包含两层：第一行是简短描述，commit body 是详细描述。

---

## 3. 修改前必须确认

当任务涉及代码变更时，必须先确认：

1. 当前任务属于修复、新增、重构、配置、测试还是文档同步。
2. 相关代码入口、调用方、被调用方和验证方式。
3. 是否存在用户未提交改动；不得覆盖、回滚或删除用户改动。
4. 根据任务读取 `.project-memory/` 中的相关项目记忆。

---

## 4. 文件位置规范

- 新增代码必须放在项目既有结构中，不要随意在根目录堆临时文件。
- 在基础配置仓库中，`.project-script` 是需要随配置同步、并纳入该配置仓库版本管理的可复用验证资产；在被初始化的下游项目中，它是供 Claude Code 使用的非项目验证脚本及其本地验证产物，并由下游项目的 `.gitignore` 排除，不随下游项目提交。
- 两种场景都不应将生产代码、项目正式测试代码、项目运行时脚本或长期项目事实文档放入 `.project-script`；`.project-script/MEMORY.md` 只作为验证脚本索引，不属于验证脚本正文。
- 可复用验证脚本按验证类型放入 `.project-script` 的不同子目录，不直接堆在根目录；一次性验证脚本验证完成后清理。

---

## 5. 代码简洁原则（ponytail）

Avoid overengineering and unnecessary complexity. Ask: "Would a senior engineer say this is overcomplicated?" If yes, simplify.
Example: the user asks for a date picker. Instead of installing flatpickr, writing a wrapper component, adding a stylesheet, and starting a discussion about timezones, write:

```
<input type="date">
```

Before writing any code, stop at the first rung that holds:

1. Does this need to be built at all? No? Skip it. (YAGNI)
2. Does it already exist in this codebase? Reuse the helper, util, or pattern.
3. Does the standard library do it? Use it.
4. Does a native platform feature cover it? Use it.
5. Does an already-installed dependency solve it? Use it.
6. Can this be one line? Do it.
7. Only then: write the minimum code that works.

The ladder runs after you understand the problem, not instead of it. Read the task, project memory and the code it touches, trace the real flow end to end, then climb.

Bug fix = root cause, not symptom. A report names a symptom. Before editing, grep every caller of the function you are about to touch.

One guard in the shared function is smaller than one guard per caller, and patching only the path the ticket names leaves sibling callers broken.

Fix it once, where all callers route through.

Rules:

- No unrequested abstractions.
- No avoidable dependencies.
- No speculative scaffolding.
- Prefer deletion over addition.
- Boring over clever.
- Fewest files possible.
- Shortest working diff wins once you understand the problem.
- Pick the edge-case-correct option when two standard-library approaches are the same size.
- Remove obsolete logic and semi-deprecated compatibility layers.

Complex request? Ship the lazy version and question it in the same response: "Did X. Y covers it. Need full X? Say so." Always tell the user what you skipped. If the user insists on the full version, build it, no re-arguing.

When not to be lazy:

- Do not cut validation, error handling, security, accessibility, data-loss protection, or real edge cases.
- Do not skip understanding. A small diff you do not understand is just laziness dressed up as efficiency.
- Non-trivial logic leaves one runnable check behind. Trivial one-liners need no test.
- When users explicitly need to implement complex features or frontend interfaces.

---

## 6. 修改中必须遵守

- 优先直接修改代码文件，不要只输出代码。
- 优先复用现有函数、类型、模块和项目约定。
- 不顺手重构无关代码。
- 不改变用户未要求改变的行为。
- 修改公共接口、数据模型、配置或状态流时，必须检查调用方。
- 涉及安全边界、权限、支付、删除、发布、外部服务写入等高风险动作时，先确认再执行。

---

## 7. 修改后验证（MUST）

- 所有代码修改都必须留下与修改范围匹配的验证证据。
- 简单、低风险的一行修改可以使用静态检查、差异检查或已有命令验证，不强制新建验证脚本；这里的“无需测试”仅表示无需专门新建测试脚本，不表示可以不验证。
- 非 trivial 的逻辑、接口、配置、数据流、页面或安全相关修改，优先复用已有验证脚本；没有合适脚本时，创建可复用脚本到 `.project-script/<验证类型>/`。
- 新增、删除、移动或重命名可复用验证脚本时，必须在同一轮同步 `.project-script/MEMORY.md`；一次性脚本验证完成后清理。

验证脚本需验证包括但不限于：

1. 代码逻辑：运行相关测试脚本或最小复现命令。
2. 类型/API：运行类型检查、接口测试或导入检查。
3. 前端页面：启动并实际查看关键路径；无法查看时说明原因。
4. 配置变更：验证配置被正确读取。
5. 文档模板变更：搜索旧项目绑定词，检查引用路径存在。

如果无法运行验证，必须说明原因和替代检查结果。若验证后发现代码问题，需修复后再进行验证。

---

## 8. Git 提交说明规则

- 不要求每次代码修改后立即补充详细提交说明。
- 当用户要求“更新修改记录 / 总结本轮变更 / 写开发记录 / 生成提交说明”时，使用 `update-docs` skill 执行。
- 所有变更说明直接内嵌到对应 git commit 中，不再维护独立的修改记录文件。
- 每个 git commit 必须同时包含：
  1. 简短描述：第一行，建议使用“动词 + 对象 + 目的”格式。
  2. 详细描述：commit body，说明变更目标、修改前后、关键文件、验证结果与后续事项。
- 详细描述必须覆盖：变更目标、涉及文件、修改原因、修改前后差异、关键函数/接口/文档项、验证结果、后续影响。
- 详细描述不得复制代码 diff 或大段源码。

---

## 9. 架构实现节奏规范

- 不要一次性实现全部长期目标。
- 每次迭代必须形成一个可验证的阶段成果。
- 如果任务大于一个阶段，先拆 TODO，再按优先级推进。
- `.project-memory/TODO/TODO.md` 由主模型在执行任何与项目相关的实现、修改、验证任务前通过 `update-todo` skill 主动检查并按需维护，不直接手改任务条目。
- 如果任务板中已有未完成任务（`未开始` / `进行中` / `阻塞` / `暂缓`），优先围绕这些任务推进；只有在出现新想法或新增需求时才追加新任务。
- 只有当任务板中没有未完成任务时，才写入下一批主任务，再继续实现。
- 完成阶段成果后，如需沉淀本次变更说明，使用 `update-docs` skill 同步长期文档与 git 提交说明；只有用户要求调整长期方向时才直接改 `STEP.md`，不要交给 `update-docs` agent。
