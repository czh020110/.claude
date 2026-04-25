# graph_prompt

## 统一 system prompt 与动态 prompt 的占位符职责(最新修改)

- 修改的文件名和路径(单个文档只写一次):
  - `backend/graph/graph_prompt.py`

- 修改前存在的问题:
  - persona/task 固定上下文没有集中定义在 prompt 模板文件中。
  - `decide_input` / `validate_input` 曾混入固定 run 上下文，动态输入职责不够清晰。
  - 决策 prompt 中“帮助 persona 完成任务”的表述不符合 agent 扮演 persona 的定位。

- 添加前未完成的功能:
  - 缺少带 `{persona}`、`{task}` 占位符的 decide/validate system prompt 模板。
  - 缺少只承载动态页面事实、历史摘要和最近步骤的 step 输入模板。

- 如何修复的(关键修改点说明):
  - 在 `decide` system prompt 中加入 `{persona}`、`{task}` 占位符，并改为“扮演 persona”。
  - 在 `validate` system prompt 中加入 `{persona}`、`{task}` 占位符。
  - 将 `decide_input` / `validate_input` 调整为只包含动态上下文。
  - 将动作列表收敛到当前 `ActionInput` 支持的 `click`、`fill`、`wait`、`navigate`。

- 修改后的预期功能或修复后的预测结果:
  - prompt 模板结构更清晰：system prompt 管固定 persona/task 和规则，input prompt 管每步动态事实。
  - 后续新增 persona/task 时只需在 run 初始化阶段填充模板。

## 为 decide agent 输入补充历史步骤详情(最新修改)

- 修改的文件名和路径(单个文档只写一次):
  - `backend/graph/graph_prompt.py`

- 修改前存在的问题:
  - `decide_input` 只提供 `previous_steps_count`，只能让 agent 知道历史步数，不能知道之前具体执行了什么。

- 添加前未完成的功能:
  - 决策 agent 缺少历史动作、执行结果和验证结论上下文。

- 如何修复的(关键修改点说明):
  - 在 `decide_input` 中新增 `previous_steps` 占位符。
  - 由图节点将历史 `StepLog` 序列化后传入 prompt。

- 修改后的预期功能或修复后的预测结果:
  - `decide_agent` 能结合历史步骤详情进行下一步动作决策。
  - agent 更容易避免重复点击、重复等待或重复填写等无效行为。

## 新增 validate agent 的验证提示词与输入模板(最新修改)

- 修改的文件名和路径(单个文档只写一次):
  - `backend/graph/graph_prompt.py`

- 修改前存在的问题:
  - 图中已有动作决策 agent 的 prompt，但没有对应的进展验证 agent prompt。
  - `validate_current_progress` 若改为 agent 验证，缺少可复用的 system prompt 和用户输入模板。

- 添加前未完成的功能:
  - validate agent 无法获得稳定的验证职责说明、输出 JSON 字段约束和输入上下文格式。

- 如何修复的(关键修改点说明):
  - 新增 `validate`，说明验证 agent 的职责、输出字段和成功/失败/继续判断原则。
  - 新增 `validate_input`，用于传入 task、latest_page_state、execution_result、previous_steps、current_step_index 和 max_steps。

- 修改后的预期功能或修复后的预测结果:
  - `demo_run_graph.py` 可以像 `decide_agent` 一样构造 validate agent 输入。
  - 验证节点可以通过结构化输出得到 `ValidationResult`。
