---
name: image-generate
description: 当用户要求生成图片、生图、出图、根据描述画图、生成海报/插画/产品图/头像/封面等图片资产时使用；先把用户需求优化为高质量英文图片生成提示词，再调用脚本请求 OpenAI Images 兼容接口，图片保存到 .claude_introduction/IMAGE，元数据保存到 .claude/.cache/image。
---

使用 OpenAI Images API 兼容接口生成图片。不要在 skill 或脚本中硬编码 API Base URL 或 API Key。

## 配置要求

从 `.claude/settings.local.json` 的 `env` 中读取以下环境变量：

- `OPENAI_IMAGE_URL`：图片 API Base URL。
- `OPENAI_IMAGE_API_KEY`：Bearer Token API Key。

如果任一变量为空，不要猜测或补写真实值；提示用户在 `.claude/settings.local.json` 的 `env` 中配置。

## 工作流程

1. 先根据用户需求生成一段优化后的英文图片 prompt。
2. 选择合法 `size`，默认 `2048x2048`。
3. 调用脚本生成图片。
4. 图片保存到 `.claude_introduction/IMAGE/`，元数据 JSON 保存到 `.claude/.cache/image/`。
5. 更新 `.claude_introduction/IMAGE/IMAGE.md`，追加图片索引，便于之后按需查看已有图片资产。
6. 回复用户时说明优化后的 prompt、图片路径、元数据路径、尺寸、索引更新和验证结果。

## 基础提示词要求

生成最终 prompt 时，把用户需求自然融入下面这组质量约束，不要机械堆关键词：

```text
Create a refined, tasteful image with natural composition, believable lighting, restrained colors, and coherent visual hierarchy. Avoid the typical over-saturated AI-generated look, plastic textures, excessive glow, cluttered details, distorted text, fake UI elements, and uncanny artifacts. Use subtle contrast, realistic material behavior, clean spacing, and an editorial design sensibility. The result should feel intentionally designed by a skilled human art director, not like a generic AI render.
```

如果用户明确指定风格，以用户指定为准，但仍保留“自然、克制、不像 AI 生成图”的质量约束。若图片需要文字，只允许短标签；避免要求模型生成大段精确文字。

## 脚本路径

- `.claude/skills/image-generate/scripts/generate_image.py`

## 基础 API 参数

脚本只保留图片 API 的基础调用参数：

- `--prompt`：必填，优化后的英文图片提示词。
- `--size`：默认 `2048x2048`，可选：`1024x1024`、`2048x2048`、`1536x1024`、`1024x1536`、`3840x2160`、`2160x3840`。
- `--n`：默认 `1`。
- `--model`：默认 `gpt-image-2`。
- `--output-dir`：默认 `.claude_introduction/IMAGE`。
- `--metadata-dir`：默认 `.claude/.cache/image`。

## 图片索引

生成图片成功后，必须更新 `.claude_introduction/IMAGE/IMAGE.md`：

- 追加短编号、图片路径、元数据路径、尺寸和用途。
- 不写提示词摘要，不复制完整 API 响应或 base64 数据。
- 如果用户要求查看已有图片，优先读取 `IMAGE.md` 判断是否需要再打开具体图片或元数据。

推荐命令：

```bash
python .claude/skills/image-generate/scripts/generate_image.py \
  --prompt "Optimized English image prompt here" \
  --size 2048x2048
```

## API 约束

- Endpoint 固定为 `{OPENAI_IMAGE_URL}/v1/images/generations`。
- 请求体字段：`model`、`prompt`、`size`、`n`。
- 返回可能是 `data[].url` 或 `data[].b64_json`，脚本会分别下载或解码保存。
- 超时时间按长任务处理，脚本请求超时为 300 秒。

## 错误处理

- 如果脚本返回 `CONFIG_ERROR`，说明本地 env 未配置完整；引导用户补齐 `.claude/settings.local.json`。
- 如果 API 返回 401/429/5xx，直接报告状态码和错误摘要，不要重试刷接口。
- 如果用户只想要 prompt，不要调用脚本。
