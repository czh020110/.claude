# 项目:Synthetic User Lab

项目文档：`claude_introduction/项目文档/` (用户提供)
目标边界：@../claude_introduction/项目实现目标/目标边界.md
项目目标：@../claude_introduction/项目实现目标/项目目标.md
本地环境：@../claude_introduction/环境说明/本地开发环境.md
常用命令：@../claude_introduction/环境说明/常用命令.md
长期计划：@../claude_introduction/TODO/STEP.md
当前待办：@../claude_introduction/TODO/TODO.md
项目数据流：`claude_introduction/数据流/核心数据流.md`(按需读取)

## 执行要求

- 回答和执行前，先判断任务属于代码修改、文档更新、进度维护、修改记录、环境排查、接口查询还是架构推进。
- 代码修改时直接改文件，不要只给代码片段；除非用户明确只要示例。
- 开始开发新功能前，按照 `当前待办` 和 `项目目标`，避免偏离当前阶段。
- 修改已有功能前，先读取相关代码、数据流和 TODO，确认上下游影响。
- 完成修改后必须说明修改了哪些文件；涉及代码时说明验证方式和结果。
- 完成阶段性工作后，必须检查 Task 工具中的任务状态；已经完成的任务要立即标记为 completed，避免遗留 in_progress/pending 任务。
- 不要一次性实现全部长期目标；每次推进应形成一个可验证的阶段成果。
- 不确定第三方库、SDK、CLI、云服务或框架接口时，先委托 `docs-research` agent 查询最新官方文档或网络资料，再实现。

## 按需读取

- 需要理解调用链、状态流转、模块协作时，读取 `claude_introduction/数据流/`。
- `claude_introduction/项目文档/` 是用户维护的长期项目文档，默认只读；除非用户明确要求，不要主动写入。

## 文档组织

- 项目说明必须按 `claude_introduction/` 下的主题文件夹维护。
- 单个主题文档过长时，在同一文件夹下新增分块文件。

# TODO

项目长期方向和阶段步骤事实源，默认不随每次提交更新: @../claude_introduction/TODO/STEP.md
记录可完成并验收的细粒度小模块任务板: @../claude_introduction/TODO/TODO.md

# Git 提交说明

- 所有变更说明直接内嵌到对应 git commit 中。
- 每个 git commit 都分为两层：第一行是简短描述，commit body 是详细描述。
- 需要回顾历史时，优先读取对应 commit 的详细描述。

---
