# Claude Code 大项目模板维护

## 当前目标

维护 `claude-copy/`，使其可作为新项目 `.claude/` 模板直接复制使用。

## 执行要求

- `claude-copy/CLAUDE-COPY.md` 必须像模型执行提示词，不写模板说明书废话。
- `claude-copy/rules/` 承载规则、格式、生成规则和维护要求。
- `claude-copy/introduction/` 只承载项目事实文件；默认可以为空，不放如何填写、模板示例、生成规则。
- TODO、DONE、修改记录目录、项目说明、环境说明、数据流等具体文件只记录真实项目内容。
- 新增模板维护规则时优先更新 `rules/`，不要写进具体事实文件。
- 删除旧项目绑定内容，但不要删除原本有价值的规则强约束。

## 验证要求

修改模板后至少检查：

- `claude-copy/introduction/` 下没有 `00-如何填写.md`、`template.md`、`00-生成规则.md`。
- `claude-copy/introduction/` 下具体事实文件不包含填写教程或示例模板。
- `claude-copy/skills/update-docs/SKILL.md` 包含 TODO、DONE、修改记录、数据流等文档维护格式。
- 旧项目专属词不应残留。
