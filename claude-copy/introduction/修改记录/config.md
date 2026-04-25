# config

## 规范化 api_prefix 确保 FastAPI 路由前缀合法(最新修改)

- 修改的文件名和路径：`backend/core/config.py`
- 修改前存在的问题（修改代码）：当 `.env` 或系统环境变量中的 `SYNTHETIC_USER_LAB_API_PREFIX` 缺少开头 `/` 时，FastAPI `include_router` 会因前缀不合法而在应用导入阶段报错。
- 添加前未完成的功能（新增代码）：缺少对 API 前缀格式的最小规范化处理。
- 如何修复的（关键修改点说明）：在 `get_settings()` 创建 `Settings` 后，若 `api_prefix` 不以 `/` 开头，则补齐开头 `/`。
- 修改后的预期功能或修复后的预测结果：本地 `.env` 中即使写入 `api/v1`，运行时也会规范化为 `/api/v1`，避免 FastAPI 路由注册失败。

## 支持从项目根目录 .env 加载运行配置 (最新修改)

- 修改的文件名和路径：`backend/core/config.py`
- 修改前存在的问题（修改代码）：`app_name`、`api_prefix`、`run_step_limit` 只能使用代码内默认值，运行参数分散依赖系统环境变量，不便于本地固定项目配置。
- 添加前未完成的功能（新增代码）：缺少从项目根目录 `.env` 文件加载环境变量的能力。
- 如何修复的（关键修改点说明）：新增 `_load_dotenv()` 在模块导入时读取根目录 `.env`，并在系统环境变量未设置同名 key 时写入 `os.environ`；将 `SYNTHETIC_USER_LAB_APP_NAME`、`SYNTHETIC_USER_LAB_API_PREFIX`、`SYNTHETIC_USER_LAB_RUN_STEP_LIMIT` 接入 `Settings`。
- 修改后的预期功能或修复后的预测结果：本地可通过根目录 `.env` 统一配置应用名、API 前缀、运行步数限制、端口、base url 与 headless 等运行参数；系统环境变量仍可覆盖 `.env`。
