# LangGraph 执行流程与数据模型

本文用于理解一次 synthetic user run 如何在 LangGraph 中流转，以及核心业务对象需要保存哪些字段。

## 如何使用本文

- 当任务只涉及本文主题时，优先只加载本文作为上下文。
- 本文保留原始设计文档中的关键实现要求，并补充少量阅读说明。
- 本次拆分只改变文档组织方式，不改变原有系统架构结论。

## 8\. LangGraph 工作流设计

## 8.1 主流程

```markdown
load_persona
→ load_task
→ init_session
→ observe_page
→ retrieve_context
→ assemble_context
→ decide_action
→ execute_action
→ validate_progress
→ log_step
→ analyze_friction
→ continue_or_stop
→ finalize_report
```

---

## 8.2 关键节点说明

## 8.2.1 load_persona

加载用户画像配置。

## 8.2.2 load_task

加载任务定义、成功条件、限制条件。

## 8.2.3 init_session

启动 Playwright 浏览器会话。

## 8.2.4 observe_page

收集当前页面状态。

## 8.2.5 retrieve_context

从 RAG 层检索产品知识、历史经验、失败恢复与规则。

## 8.2.6 assemble_context

将实时页面状态与检索结果压缩为决策上下文。

## 8.2.7 decide_action

基于 persona + task + context 生成结构化动作。

## 8.2.8 execute_action

调用 Playwright 执行动作。

## 8.2.9 validate_progress

判断是否推进任务，是否进入错误态或死循环。

## 8.2.10 log_step

记录本步完整状态与截图。

## 8.2.11 analyze_friction

计算是否出现迷失、冗长、恢复困难等摩擦信号。

## 8.2.12 continue_or_stop

判断是否继续、放弃、成功结束或进入恢复分支。

## 8.2.13 finalize_report

生成最终报告并写入数据库。

---

## 8.3 异常分支

### 恢复流程

```markdown
error_detected
→ retrieve_failure_memory
→ choose_recovery_action
→ execute_recovery
→ revalidate
```

### 放弃流程

```markdown
friction_too_high / step_limit_exceeded / severe_error
→ abandon_task
→ summarize_failure
```

---

## 9\. 数据模型设计

## 9.1 Project

字段：

- id
- name
- description
- target_product
- version
- created_at

---

## 9.2 Persona

字段：

- id
- name
- skill_level
- patience_level
- risk_preference
- ambiguity_tolerance
- recovery_style
- ai_trust_level
- profile_json

---

## 9.3 Task

字段：

- id
- name
- description
- start_url
- success_criteria
- max_steps
- max_failures
- allowed_actions
- risk_level

---

## 9.4 Run

字段：

- id
- project_id
- persona_id
- task_id
- status
- started_at
- ended_at
- total_steps
- success
- friction_score
- summary

---

## 9.5 StepLog

字段：

- id
- run_id
- step_index
- observed_page_state
- retrieved_context_summary
- decided_action
- execution_result
- validation_result
- screenshot_path
- friction_signals
- created_at

---

## 9.6 FrictionIssue

字段：

- id
- run_id
- step_index
- issue_type
- severity
- description
- suggested_fix

---

## 9.7 KnowledgeArtifact

字段：

- id
- source_type
- title
- content
- metadata_json
- embedding
- created_at

---

## 9.8 FailureCase

字段：

- id
- page_type
- error_type
- symptom_summary
- successful_recovery
- failed_recovery
- severity
- metadata_json

---
