# LangChain 与 LangGraph 接口规范

本文整合自以下两份笔记，仅保留笔记中已经明确讲解、后续开发应优先采用的接口与调用方式：

- `C:\Users\Chen\OneDrive\Apps\remotely-save\Obsidian\Study\AI\Agent\LangChain.md`
- `C:\Users\Chen\OneDrive\Apps\remotely-save\Obsidian\Study\AI\Agent\LangGraph.md`

本文是接口规范，不是使用教程。未在笔记中明确讲解的接口，不纳入本规范。

---

## 1. 总体原则

- LangChain 新增链路优先使用 LCEL 管道与 Runnable 标准调用面，不使用旧式 `LLMChain` / `SimpleSequentialChain` / `SequentialChain` 作为新增实现主路径。
- LangGraph 流程优先使用 `TypedDict` 定义图状态，节点返回 state 的增量更新。
- 结构化输出优先使用 `Pydantic BaseModel` 作为输出 schema；图内状态优先使用 `TypedDict`。
- 有工具调用时优先区分两种模式：显式 `ToolNode` 回路，或 `create_agent` 内置工具调用，不混用重复工具执行层。
- 涉及多轮、HITL、时间回溯或会话连续时，必须配置 checkpointer，并在调用 config 中传入稳定的 `thread_id`。

---

## 2. LangChain 接口规范

### 2.1 模型接入与调用

#### `ChatOpenAI` / `ChatOllama`

- 适用场景：对话模型主路径。
- 推荐调用方式：先实例化模型，再使用 `model.invoke(...)`；需要流式输出时使用 `streaming=True` 并调用 `model.stream(...)`。
- 关键约束：
  - 重点配置 `model`、`base_url`、`api_key`，密钥可从环境变量读取。
  - 常用参数包括 `temperature`、`max_tokens`。
  - 返回通常是 `AIMessage` 或其他 `BaseMessage` 子类，文本内容从 `.content` 获取。

#### `OpenAI`

- 适用场景：非对话模型调用。
- 推荐调用方式：与 ChatModel 分开使用。
- 关键约束：返回处理方式与 ChatModel 不同，不按 `.content` 习惯处理非对话模型结果。

#### `DashScopeEmbeddings` / `OllamaEmbeddings`

- 适用场景：文本向量化。
- 推荐调用方式：
  - 单条文本使用 `embed_query(str)`。
  - 批量文本使用 `embed_documents(list[str])`。
- 关键约束：嵌入模型不走 `invoke` / `stream` 调用面。

#### `DashScopeRerank`

- 适用场景：对候选文档进行重排。
- 推荐调用方式：初始化时指定 `top_n`。
- 关键约束：输出只保留重排后的前 N 条。

---

### 2.2 Message 与上下文

#### `SystemMessage` / `HumanMessage` / `AIMessage` / `ChatMessage`

- 适用场景：标准化消息输入与多轮上下文。
- 推荐调用方式：优先使用 message 列表传入模型，`SystemMessage` 通常放在首条。
- 关键约束：
  - `invoke` 输入可为字符串或 message 列表。
  - 返回通常是 `AIMessage`。
  - 消息类型识别优先使用 `msg.type`；如需类名可用 `type(msg).__name__`。

#### `agent.invoke`

- 适用场景：agent 入口调用。
- 推荐调用方式：传入 state 字典，例如 `{"messages": [...]}`。
- 关键约束：agent 调用不是传裸 message，而是传包含 `messages` 的状态对象。

---

### 2.3 Prompt 模板

#### `PromptTemplate.from_template`

- 适用场景：字符串提示模板。
- 推荐调用方式：优先使用 `PromptTemplate.from_template(...)`；变量注入使用 `format(...)` 或 `invoke({...})`。
- 关键约束：
  - `format(...)` 返回 `str`。
  - `invoke(...)` 返回 `PromptValue`。
  - 默认变量使用 `partial_variables` 或 `.partial(...)`。

#### `ChatPromptTemplate.from_messages`

- 适用场景：多角色对话提示模板。
- 推荐调用方式：使用 `ChatPromptTemplate.from_messages([...])` 构造；需要插入历史或不确定角色消息时使用 `MessagesPlaceholder`。
- 关键约束：
  - 模板需要先 `invoke` / `stream` 形成可传给模型的输入。
  - `ChatPromptTemplate` 的 partial 默认值使用 `.partial()`。

---

### 2.4 输出解析

#### `StrOutputParser`

- 适用场景：将 ChatModel 返回统一转为字符串。
- 推荐调用方式：`prompt | model | StrOutputParser()`。
- 关键约束：用于提取文本内容。

#### `JsonOutputParser`

- 适用场景：结构化 JSON 输出。
- 推荐调用方式：通过 `parser.get_format_instructions()` 将格式要求注入 prompt，再使用 `prompt | model | parser`。
- 关键约束：必须在提示词中明确约束 JSON 输出格式。

#### `XMLOutputParser`

- 适用场景：XML 约束输出后的结构化解析。
- 推荐调用方式：先将 XML 格式要求注入模板，再接入解析器。
- 关键约束：解析结果是结构化对象，不是原始 XML 字符串。

#### `CommaSeparatedListOutputParser`

- 适用场景：逗号分隔列表输出。
- 推荐调用方式：使用 `get_format_instructions()` 生成格式说明，并接入 LCEL 管道。
- 关键约束：模型输出必须符合逗号分隔列表格式。

---

### 2.5 LCEL 与 Runnable 编排

#### LCEL 管道 `|`

- 适用场景：链式主编排。
- 推荐调用方式：`chain = prompt | model | parser`。
- 关键约束：新增链路统一使用 `invoke` / `stream` / `batch` 调用。

#### Runnable 标准调用面

- 适用场景：统一组件调用语义。
- 推荐调用方式：
  - 单条调用：`invoke(...)`。
  - 流式调用：`stream(...)`。
  - 批量调用：`batch(...)`。
  - 异步调用：`ainvoke(...)` / `astream(...)` / `abatch(...)`。
- 关键约束：需要入链的组件应遵循 Runnable 协议。

#### `RunnableParallel`

- 适用场景：同一输入并行运行多个分支并打包为新字典。
- 推荐调用方式：显式使用 `RunnableParallel(...)`，或在 LCEL 中使用字典隐式转换。
- 关键约束：输出是新字典，未显式保留的原输入字段会丢失。

#### `RunnablePassthrough.assign`

- 适用场景：保留上一步输入，同时追加新键。
- 推荐调用方式：`RunnablePassthrough.assign(key=some_chain)`，可串联多步保存中间态。
- 关键约束：适合多键传递链路，优先用于替代旧式 SequentialChain 的变量传递写法。

#### `itemgetter` / `lambda`

- 适用场景：从输入字典抽取指定键传给下游模板或 retriever。
- 推荐调用方式：`itemgetter("input") | retriever | format_func`。
- 关键约束：当下游只接收字符串而上游输入是 dict 时，必须先抽取目标键。

#### `@chain`

- 适用场景：将包含自定义逻辑的函数封装为可组合 Runnable。
- 推荐调用方式：对自定义函数使用 `@chain` 装饰后接入 LCEL 管道。
- 关键约束：装饰后具备 `invoke` / `stream` / `batch` 能力。

---

### 2.6 Memory

#### `InMemoryChatMessageHistory`

- 适用场景：内存态会话历史。
- 推荐调用方式：使用 `add_user_message` / `add_ai_message` / `add_messages` 写入历史，传模型时使用 `history.messages`。
- 关键约束：它只负责消息存储，不负责策略裁剪。

#### `RunnableWithMessageHistory`

- 适用场景：给已有 chain 包装按 `session_id` 隔离的历史能力。
- 推荐调用方式：
  - 提供 `get_session_history(session_id)`。
  - 调用时通过 `config={"configurable": {"session_id": "..."}}` 传入会话。
- 关键约束：`input_messages_key`、`history_messages_key` 必须与模板占位键对齐。

#### `FileChatMessageHistory`

- 适用场景：文件持久化消息历史。
- 推荐调用方式：使用社区实现，或继承 `BaseChatMessageHistory` 自定义。
- 关键约束：最小接口包含 `add_messages`、`messages`、`clear`。

---

### 2.7 RAG 基础链路

#### `CSVLoader` / `JSONLoader` / `TextLoader` / `PyPDFLoader`

- 适用场景：多源文档统一加载为 `Document`。
- 推荐调用方式：
  - 常规文档使用 `load()`。
  - 大文档优先使用 `lazy_load()`。
  - `JSONLoader` 通过 `jq_schema` 抽取内容，必要时设置 `json_lines=True`。
- 关键约束：统一返回 `Document`。

#### `RecursiveCharacterTextSplitter`

- 适用场景：RAG 入库前文本切块。
- 推荐调用方式：设置 `chunk_size` / `chunk_overlap` / `separators` 后调用 `split_documents(...)`。
- 关键约束：输出仍为 `list[Document]`。

#### `InMemoryVectorStore` / `Chroma`

- 适用场景：向量入库与检索。
- 推荐调用方式：使用 `add_documents` / `delete` / `similarity_search`。
- 关键约束：检索返回 `list[Document]`。

#### `as_retriever()` + `RunnablePassthrough` / `itemgetter`

- 适用场景：将 retriever 接入 LCEL RAG 链路。
- 推荐调用方式：
  - 使用 `retriever = vector_store.as_retriever(...)`。
  - 使用字典装配、`RunnablePassthrough` 或 `itemgetter` 保留 `input` / `history` 等原始输入。
- 关键约束：不要直接 `retriever | prompt` 导致原始输入丢失。

---

## 3. LangGraph 接口规范

### 3.1 图与状态建模

#### `StateGraph(state_schema, config_schema=None)`

- 适用场景：构建有状态流程图。
- 推荐调用方式：先定义 `TypedDict` 状态，再注册节点和边，最后统一 `compile()`。
- 关键约束：
  - `state_schema` 优先使用 `TypedDict`。
  - 节点函数遵循 `State -> Partial`，优先返回 state 的增量更新。

#### `add_node(name, node_fn)` / `add_edge(src, dst)`

- 适用场景：注册节点与普通顺序流。
- 推荐调用方式：用 `START` / `END` 显式连接入口和出口。
- 关键约束：节点函数读取 state，返回 dict 增量更新。

#### `compile(...)`

- 适用场景：将图定义转为可执行运行时对象。
- 推荐调用方式：所有节点和边声明完成后统一调用。
- 关键约束：返回支持 `invoke(...)` / `astream(...)` 等调用的对象，编译阶段会进行结构检查。

#### `invoke(input, config=...)` / `astream(input, config=...)`

- 适用场景：同步调用与事件流输出。
- 推荐调用方式：普通请求用 `invoke`；循环、长流程或需要过程输出时用 `astream`。
- 关键约束：启用 checkpointer 时，`config` 必须携带 `configurable.thread_id`。

#### `Annotated[..., add_messages]`

- 适用场景：messages 状态字段自动合并。
- 推荐调用方式：在 `AgentState.messages` 上声明 `Annotated[list, add_messages]`。
- 关键约束：`Annotated` 本身不改变行为，LangGraph 会读取其中的 `add_messages` 作为 reducer 规则。

---

### 3.2 条件路由与循环

#### `add_conditional_edges(source, path, path_map=None)`

- 适用场景：条件分支、循环、并行扇出。
- 推荐调用方式：
  - `path` 直接返回节点名或节点名列表。
  - 或让 `path` 返回标记值，再通过 `path_map` 映射到真实节点。
- 关键约束：
  - 返回 list 表示并行进入多个目标节点。
  - 只有当 `path` 不直接返回节点名或节点名列表时才需要 `path_map`。

---

### 3.3 子图复用

#### 子图作为节点

- 适用场景：复用已编译图，或在多团队/多 Agent 场景下集成子流程。
- 推荐调用方式：
  - 主图和子图状态字段同名时，可直接将已编译 app 作为节点加入主图，或直接 `app.invoke(state)`。
  - 主图和子图字段不一致时，在包装节点中显式做字段映射后再调用 `app.invoke(...)`。
- 关键约束：触发子图节点本质上是一次 `subgraph.invoke(state)`。

---

### 3.4 工具调用模式

#### `ToolNode(tools=[...])`

- 适用场景：模型 `bind_tools` 后需要显式工具执行节点。
- 推荐调用方式：使用 `chatbot -> 条件边判断 tool_calls -> tool_node -> chatbot` 的回路。
- 关键约束：路由函数必须检查最后一条消息是否包含 `tool_calls`。

#### `create_agent(model, tools, ...)`

- 适用场景：由 LangChain agent 内置处理工具调用。
- 推荐调用方式：图中只保留 agent 节点，不再额外挂 `ToolNode`。
- 关键约束：笔记结论是“要用工具就用 agent，不用工具就用 model chain”。

---

### 3.5 结构化输出与类型约束

#### `model.with_structured_output(Schema, method=...)`

- 适用场景：规划、分类、路由等结构化字段输出。
- 推荐调用方式：
  - schema 使用 `Pydantic BaseModel`，字段用 `Field` 描述。
  - `method` 优先使用 `function_calling`。
- 关键约束：
  - 图 state 推荐 `TypedDict`。
  - `BaseModel` 主要用于结构化输出 schema，不作为图内状态主承载。

---

### 3.6 持久化与会话连续

#### `InMemorySaver` + `compile(checkpointer=...)` + `config.thread_id`

- 适用场景：多轮连续对话、HITL、time travel。
- 推荐调用方式：编译时挂载 checkpointer，调用时固定 `thread_id`。
- 关键约束：只有相同 `thread_id` 才能续写状态。

---

### 3.7 HITL 中断与恢复

#### `interrupt(...)` + `Command(resume=...)` + `Command(goto=...)`

- 适用场景：动态人工审批、补参、人工分支决策。
- 推荐调用方式：在节点内部用 `interrupt(...)` 暂停；外部二次调用 `invoke(Command(resume=...), config=...)` 恢复。
- 关键约束：
  - `interrupt(...)` 的返回值由 `Command(resume=...)` 注入。
  - `Command(goto=...)` 可指定下一节点，通常无需再用 `add_edge` 声明该跳转。

#### `compile(interrupt_before=[...], interrupt_after=[...])`

- 适用场景：静态断点、调试、测试、工具审批前拦截。
- 推荐调用方式：在编译期声明节点级断点。
- 关键约束：静态断点发生在节点边界，与节点内部的动态 `interrupt(...)` 区分使用。

---

### 3.8 时间回溯与分叉

#### `get_state(config)` / `get_state_history(config)`

- 适用场景：查看当前状态快照与历史 checkpoint。
- 推荐调用方式：将 history 转为 list 后处理；通过 `snapshot.next` 与 `checkpoint_id` 定位节点前后状态。
- 关键约束：历史顺序为倒序，最新 checkpoint 在前。

#### `update_state(old_snapshot.config, values=..., as_node=...)`

- 适用场景：time travel 分叉重放。
- 推荐调用方式：从旧 checkpoint fork 新分支，再使用 `invoke(None, config=new_config)` 继续执行。
- 关键约束：
  - 默认在同一个 `thread_id` 下分叉，不新建 thread。
  - 如需从特定位置继续，需指定 `as_node`。

---

### 3.9 记忆分层

#### `BaseStore` / `InMemoryStore` + `store.put(...)` / `store.search(...)`

- 适用场景：跨线程长期记忆。
- 推荐调用方式：
  - 使用命名空间分层，例如 `("memories", user_id)`。
  - 节点签名通过 `*, store: BaseStore` 注入 store。
  - 写入使用 `store.put(namespace, memory_id, info_dict)`。
  - 检索使用 `store.search(namespace, query=..., limit=...)`。
- 关键约束：
  - 不配置 embedding 时，`search` 会退化为近似最近项结果，`score=None`。
  - 长期记忆 `BaseStore` 与短期状态 `Checkpointer` 职责分离。

---

### 3.10 消息压缩

#### `SummarizationMiddleware`

- 适用场景：多轮对话上下文压缩。
- 推荐调用方式：创建 summarizer 后传入 `create_agent(..., middleware=[summarizer])`。
- 关键约束：新版本使用 `SummarizationMiddleware` 替代旧 `SummarizationNode` / `pre_model_hook` 方式。

---

## 4. 明确不纳入本规范的内容

- 未在两份笔记中明确讲解的接口和调用方式。
- 仅概念介绍、无明确接口约束的内容。
- 旧链式 API 的新增实现使用方式：`LLMChain`、`SimpleSequentialChain`、`SequentialChain`。
- 笔记中标注为旧版本或已移除的接口，例如 `DatetimeOutputParser`。
- 通用 Python 教学片段，例如 `map`、`Any`、`Optional`、`Union` 的基础语法演示。
- 仅作为外部参考入口的链接、博客、API 文档卡片、LangSmith 链接。
- 未形成明确项目调用规范的工具、模型网关个性化参数或教学示例代码。
