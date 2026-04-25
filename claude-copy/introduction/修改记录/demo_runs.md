# demo_runs

## pending task 占位记录改用 success_criteria(最新修改)

- 修改的文件名和路径(单个文档只写一次):
  - `backend/api/routes/demo_runs.py`

- 修改前存在的问题:
  - API 启动 run 时创建的 pending task 仍使用旧字段 `success_text`。
  - `DemoTask` 改为 `success_criteria` 后，占位记录结构不一致。

- 添加前未完成的功能:
  - 缺少与新 task schema 对齐的 pending run 占位 task。

- 如何修复的(关键修改点说明):
  - 将 pending task 的成功条件字段改为 `success_criteria=["页面出现提交成功文案"]`。

- 修改后的预期功能或修复后的预测结果:
  - API 创建 queued run 时的占位记录与新的 `DemoTask` schema 一致。
