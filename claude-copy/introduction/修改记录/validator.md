# validator

## 使用 success_criteria 列表判断任务成功(最新修改)

- 修改的文件名和路径(单个文档只写一次):
  - `backend/analysis/validator.py`

- 修改前存在的问题:
  - 规则验证函数依赖 `DemoTask.success_text` 单一成功文案。
  - `DemoTask` 改为 `success_criteria` 后，旧验证逻辑无法匹配新的任务结构。

- 添加前未完成的功能:
  - 缺少基于多条成功条件判断任务成功的规则验证逻辑。

- 如何修复的(关键修改点说明):
  - 将成功判断改为遍历 `task.success_criteria`。
  - 任一成功条件出现在页面可见文本摘要中，即返回 `succeeded`。

- 修改后的预期功能或修复后的预测结果:
  - 规则验证函数与新的 `DemoTask.success_criteria` 字段保持一致。
  - 后续 task 可以配置多条成功判定文本。
