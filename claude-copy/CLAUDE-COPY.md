项目:Synthetic User Lab

# 项目环境说明

项目环境: @introduction/环境说明/关键的环境说明文档.md

## 运行验证注意事项

- 默认使用 `synthetic-user-lab` Conda 环境，避免系统 Python 缺少 Playwright 等依赖。
- FastAPI 本地验证优先使用端口 `8765`：`python -m uvicorn backend.main:app --host 127.0.0.1 --port 8765`。
- Windows 下如需脚本输出中文 JSON，优先直接调用环境 Python：`D:/Env/Anaconda/Anaconda3-2024.06-1/envs/synthetic-user-lab/python.exe`，避免 `conda run` 的 GBK 转码问题。
- 复杂异步或 HTTP 轮询验证不要塞进 `python -c` 单行命令，优先使用 heredoc、临时脚本或直接环境 Python 执行。

# 项目实现目标说明

## 分块文档说明

1. 项目定位、边界与设计原则
   @introduction/项目实现目标-v1/01-项目定位边界与设计原则.md
   - 用于理解项目为什么存在、解决什么问题、第一阶段边界与核心设计原则。

2. 功能模块与 API 接口
   @introduction/项目实现目标-v1/02-功能模块与API接口.md
   - 用于实现 persona、task、observer、planner、validator、report 等功能模块和基础 API。

3. RAG 记忆与上下文系统
   @introduction/项目实现目标-v1/03-RAG记忆与上下文系统.md
   - 用于实现产品知识库、UI 经验库、失败恢复库、评测规则库和检索策略。

4. 系统架构、技术栈与存储职责
   @introduction/项目实现目标-v1/04-系统架构技术栈与存储职责.md
   - 用于搭建项目目录、技术栈选型、服务分层以及 PostgreSQL / Redis 职责划分。

5. LangGraph 执行流程与数据模型
   @introduction/项目实现目标-v1/05-LangGraph流程与数据模型.md
   - 用于实现 run 流程、异常恢复分支以及 Project / Persona / Task / Run / StepLog 等数据对象。

6. 安全边界与 MVP 路线图
   @introduction/项目实现目标-v1/06-安全边界与MVP路线图.md
   - 用于判断 MVP 先做什么、哪些操作必须限制，以及后续阶段如何演进。

# 项目代码数据流

项目代码数据流说明: @introduction/数据流/代码数据流

# 技术接口规范

LangChain 与 LangGraph 接口规范: @introduction/LangChain与LangGraph接口规范.md

# TODO

项目整体计划步骤: @introduction/TODO/Steps.md

当前项目已完成具体模块功能点: @introduction/TODO/DONE.md

# 修复记录

修复记录的代码修改目录:
`.claude\introduction\修改记录\目录.md` (按需查看)

## 已有代码修复记录的文档路径

.claude/introduction/修改记录/graph_prompt.md

.claude/introduction/修改记录/demo_runs.md

.claude/introduction/修改记录/validator.md

.claude/introduction/修改记录/config.md

.claude/introduction/修改记录/demo_run_graph.md

.claude/introduction/修改记录/in_memory_run_store.md

.claude/introduction/修改记录/playwright_adapter.md

.claude/introduction/修改记录/run_schemas.md
