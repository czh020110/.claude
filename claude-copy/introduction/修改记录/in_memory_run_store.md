# in_memory_run_store

## 修复 complete_run 清空失败错误信息导致状态排查困难的问题(最新修改)

- 修改的文件名和路径(单个文档只写一次):
  - `backend/stores/in_memory_run_store.py`

- 修改前存在的问题:
  - `complete_run` 会无条件清空 `error_message`，导致失败报告落库后丢失失败原因。

- 添加前未完成的功能:
  - 失败结果写回后保留错误信息的能力缺失。

- 如何修复的(关键修改点说明):
  - 将 `complete_run` 的错误信息清空逻辑改为仅在 `report.status == "succeeded"` 时执行。

- 修改后的预期功能或修复后的预测结果:
  - 失败状态保留失败原因，便于状态接口与失败报告联动排查。
