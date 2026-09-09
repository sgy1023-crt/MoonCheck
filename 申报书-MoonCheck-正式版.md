# MoonCheck —— 基于 MoonBit 的轻量级 JSON / API 参数校验库与 CLI

## 一、一句话简介

MoonCheck 是一个用 MoonBit 实现的轻量级、可复用的 JSON / API 参数校验库，并提供一个命令行工具（CLI）；它根据简单的 Schema 描述对 JSON 数据做校验，返回清晰、结构化的错误信息。

## 二、项目背景与目标

REST API 请求参数、JSON 配置文件、以及大模型 Agent 的 Tool Call 参数，都需要在做进一步处理前先被"检查一遍"：字段是否齐全、类型是否正确、取值范围是否合法。现有做法要么依赖重量级的 JSON Schema 标准与框架，要么与特定运行框架强绑定。

本项目目标：用 MoonBit 提供一个**小而完整**、可被任何上层直接复用的通用校验工具，而不只是服务于 MoonBit 自身。MoonCheck 是通用的开发工具，核心实现全部使用 MoonBit 编写，仅依赖 MoonBit 官方标准库。

## 三、主要功能

- 支持的数据类型：`string`、`number`、`int`、`bool`、`object`、`array`。
- 支持的约束：
  - 对象：必填 / 可选字段、任意层级的嵌套对象；
  - 数组：元素类型约束、最小 / 最大元素个数；
  - 字符串：最小 / 最大长度（按字符数）；
  - 数值：最小值 / 最大值（含边界）；
  - 任意属性：枚举值白名单（`enum`）。
- 错误输出结构化：每条错误包含 JSON Pointer 式**路径**（如 `$.user.age`、`$.tags[0]`）、机器可读的错误分类、以及人类可读的原因（如 `expected Int, got String`、`required field is missing`）。
- 校验时**收集全部问题**，而不是遇到第一个错误就停止。
- Schema 以普通 JSON 文档描述，跨语言易读、易于维护；也支持直接在 MoonBit 代码中构造。
- CLI：`mooncheck validate schema.json data.json`，支持 `--help` / `--version`；退出码约定：0 表示校验通过、非 0 表示失败，并打印错误。

## 四、典型使用场景

1. **REST API 请求参数校验**：对入参中的 username、age、email 等字段做合法性检查后再交给业务处理；
2. **配置文件校验**：工具读取 JSON 配置时，检查必填项、类型与取值范围；
3. **AI Agent / LLM Tool Calling 参数校验**：模型产出 Tool Call（如 `{"action":"click","x":123,"y":456}`）后，先校验字段、类型与范围，再交给执行器，避免把非法参数传给真实动作。

## 五、技术实现与质量

- 主体语言：MoonBit；库本体除官方标准库外无第三方依赖。
- 采用 MoonBit 官方推荐的项目结构（库包 + `cmd/main` 可执行包），并提供默认后端即可运行的可执行示例 `examples/demo`。
- 测试：`moon test` 全部通过，共 43 项，覆盖各类型的正常与失败路径（必填缺失、类型错误、min/max 越界、字符串长度、枚举不匹配、嵌套对象字段错误、数组元素类型错误及路径定位），以及 Schema 解析与端到端校验。
- 文档：README 包含 Features、安装构建、Quick Start、Schema 与校验示例、CLI 用法、三类 Use Cases、测试与项目结构说明；仓库随附 LICENSE（Apache-2.0）。

## 六、仓库与复现

- 代码仓库（public）：https://github.com/sgy1023-crt/MoonCheck
- 复现步骤：
  ```bash
  moon check              # 类型检查
  moon test               # 运行 43 项测试
  moon run examples/demo  # 运行演示
  ```
- 说明：CLI 为 native 目标，Windows 上构建可执行文件需要 MSVC 工具链（或使用 Linux / macOS 的系统 C 工具链）；CLI 复用的校验逻辑已通过全后端测试覆盖。
