# Lua API

## 主模块

```lua
local luma = require("luma")
```

### `setup(opts?)`

应用配置，根据 `opts.tools` 重置工具注册表，销毁已有 UI 对象，并新建内存中的 Chat 会话。

```lua
luma.setup({
  model = "openrouter",
  models = { ... },
})
```

返回 `luma` 模块。

### Chat 控制

```lua
luma.toggle()
luma.submit(text?)
luma.cancel()
luma.new()
luma.resend()
```

- `toggle()` 显示或隐藏主界面。
- `submit()` 提交传入文本或当前 Prompt 内容。
- `cancel()` 取消主请求和正在运行的一次性工具请求。
- `new()` 新建主 Chat 会话。
- `resend()` 删除最后一条 Assistant 回复并重新发送最后一条 User 消息。

### 模型

```lua
luma.model(name?)
```

传入已配置名称时直接切换；省略名称时打开选择器。

### 工具

```lua
luma.tool(name, has_range?)
```

运行已注册工具。`has_range` 用于说明工具是否应读取当前 Visual 选择。

## 历史记录

历史选项使用以下作用域：

```lua
{ scope = "chat" }
{ scope = "tool", tool = "translate" }
{ scope = "all" }
```

`scope = "all"` 只用于交互式历史浏览。

### 浏览历史

```lua
luma.history()
luma.history({ scope = "tool", tool = "translate" })
luma.history({ scope = "all" })
```

该函数会打开选择器，删除前可能弹出确认。

### 删除一条记录

```lua
local ok, err = luma.history_delete(id, {
  scope = "tool",
  tool = "translate",
})
```

该函数不弹确认，只接受命名作用域，并忽略任意 path 字段。

删除当前主 Chat 记录时，会同时重置内存会话，避免下次保存重新创建已删除文件。

### 清空作用域

```lua
local result, err = luma.history_clear({ scope = "chat" })
```

结果包含删除数量和单个文件失败信息：

```lua
{
  deleted = 12,
  failed = {
    { id = "...", error = "..." },
  },
}
```

该函数不弹确认。

## 工具注册表

```lua
local tools = require("luma.tools")
```

### 注册

```lua
tools.register(name, spec)
tools.unregister(name)
```

`spec` 可以是声明式表、带有 `run(ctx)` 的表，或一个接收 `ctx` 的函数。

### 查询

```lua
local spec = tools.get(name)
local names = tools.names()
```

### 运行和取消

```lua
tools.run(name, has_range?)
tools.cancel()
```

`cancel()` 会取消所有正在运行的一次性工具请求，并返回是否实际取消了请求。

### 替换注册表

```lua
tools.setup(definitions?)
```

该函数会取消正在运行的一次性请求，清空注册表，并注册所有不为 `false` 的定义。

## Tool context

自定义工具的 `ctx` 提供：

```lua
ctx.name
ctx.tool
ctx.has_range
ctx.visual()
ctx.source(has_range?)
ctx.generate(spec)
ctx.chat(spec)
ctx.cancel()
ctx.loading(opts?)
ctx.panel(title, keys?, opts?)
ctx.strip_fence(text)
```

示例和字段说明见[编写工具](tools.zh-CN.md)。
