# run_schemas

## 调整 RunRequest 与 DemoTask 的职责边界(最新修改)

- 修改的文件名和路径：`backend/schemas/run_schemas.py`
- 修改前存在的问题（修改代码）：`RunRequest` 中包含 `expected_user_name`、`expected_email`、`operator_note` 等 demo 固定输入，容易把测试数据和启动请求耦合在一起；`DemoTask` 只用 `success_text` 描述成功条件，不利于后续扩展多条成功标准。
- 添加前未完成的功能（新增代码）：缺少把具体填写示例和测试目标归入 task description、把成功标准抽象为列表的结构。
- 如何修复的（关键修改点说明）：删除 `RunRequest` 中的固定用户名、邮箱和备注字段；将 demo 表单填写要求写入 `DemoTask.description`；用 `success_criteria: list[str]` 替代 `success_text`。
- 修改后的预期功能或修复后的预测结果：启动请求只负责启动 run，任务定义负责说明要测试的功能和可选示例数据；后续同一个 persona 可以执行不同 task，每个 task 自带测试目标说明。

## 补充 DemoPersona 用户画像字段注释 (最新修改)

- 修改的文件名和路径：`backend/schemas/run_schemas.py`
- 修改前存在的问题（修改代码）：`skill_level`、`patience_level`、`risk_preference` 三个字段只有默认值，学生阅读时不容易理解它们分别代表用户熟练度、耐心程度和风险偏好。
- 添加前未完成的功能（新增代码）：本次未新增功能，只补充数据模型字段说明。
- 如何修复的（关键修改点说明）：在 `DemoPersona` 模型中为三个字段添加中文行内注释，说明 `newbie`、`medium`、`low` 在当前 demo persona 中的含义。
- 修改后的预期功能或修复后的预测结果：阅读 `DemoPersona` 时可以直接理解三个 persona 参数的行为含义，便于后续扩展更多用户画像。
