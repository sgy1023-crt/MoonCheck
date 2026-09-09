# FACTS — MoonCheck 客观事实记录

> 仅供撰写申报书时引用的事实清单。本项目申报书正文请自行撰写，
> 不要直接提交本文件或由 AI 代写申报书。

## 项目基本信息

- 项目名：MoonCheck
- 仓库本地路径：`H:\claude code workspace\2026 MoonBit 国产基础软件开源大赛 - 9 月黑客松\MoonCheck`
- GitHub 仓库：https://github.com/sgy1023-crt/MoonCheck （**public，已推送**，默认分支 main）
- moon.mod 模块名：`sgy1023-crt/MoonCheck`
- 主要实现语言：MoonBit（标准库：`moonbitlang/core` 的 json / double / debug 等）
- 使用的 MoonBit 工具链：moon 0.1.20260904（2026-09-04 构建）
- 唯一非 MoonBit 运行时依赖：`moonbitlang/async@0.21.3`，仅用于 native CLI 的文件读取；库本体零第三方依赖
- 许可证：Apache-2.0（LICENSE 文件为 Apache-2.0 全文）
- 版本：0.1.0

## 已实现功能（全部经过测试）

- 支持的 schema 类型：string / number / int / bool / object / array
- 支持的约束：
  - object：必填/可选字段、任意嵌套 object、忽略未声明字段
  - array：元素类型（items）、minItems / maxItems
  - string：minLength / maxLength（按字符数）
  - int / number：min / max（含边界）
  - 任意属性：enum（字面量列表）
- 校验引擎：收集**全部**错误而非首个；错误含 JSON Pointer 式路径（`$.user.age`、`$.tags[0]`）、机器可读分类、人类可读信息（如 `expected Int, got String`）
- 解析器：schema 文档（JSON）→ 类型化 schema；schema 错误抛出带原因的 `SchemaError`
- 库 API：`validate`、`is_valid`、`parse_schema_string`、`validate_strings`（字符串直达，端到端）
- CLI：`cmd/main`，命令 `mooncheck validate schema.json data.json`（`validate` 可省略）；支持 `--help`/`--version`；退出码 0=有效 / 1=校验失败 / 2=用法或 IO 错误
  - **平台限制（事实）**：CLI 为 native 目标；Windows 需 MSVC 工具链（async 在 Windows 仅支持 MSVC；本开发机无 MSVC，故 native CLI 未在本机实跑），Linux/macOS 用系统 C 工具链即可。CLI 复用的 `validate_strings` 逻辑已在全后端测试覆盖。
- 运行示例：`examples/demo`（`moon run examples/demo`，默认后端即可运行）；`examples/cli/` 提供 schema/data 样例文件

## 测试

- 测试文件：`MoonCheck_test.mbt`（黑盒/公共 API）、`MoonCheck_wbtest.mbt`（白盒/内部）
- `moon test` 通过；测试数：**43/43**（最后核实时）
- 覆盖：每类正常与失败路径、必填缺失、类型错误、min/max 越界、字符串长度、enum 不匹配、嵌套 object 字段错误、array 元素类型错误（含 `$.tags[0]` 路径）、schema 文档解析（合法与非法）、端到端 validate_strings

## 三个实际使用场景（README 均已体现并有示例）

1. REST API 请求参数校验（username / age / email 等）
2. JSON 配置文件校验（必填项、类型、范围）
3. AI Agent / LLM Tool Calling 参数校验（校验 action / x / y 后再交给执行器）

## Git 状态

- commit 数：12（截至最终核对时；均为真实、独立、可构建的内容变更）
- commit 均为真实、独立、可构建的内容变更（初始化 / 类型 / 引擎 / 测试 / 解析器 / CLI / 端到端测试 / 示例等）
- 提交作者（repo 本地 config）：`sgy1023-crt <143707312+sgy1023-crt@users.noreply.github.com>`

## 验证命令

```bash
moon check            # 类型检查通过
moon test             # 43 项测试全通过
moon run examples/demo
# native CLI（需 MSVC 或 Linux/macOS C 工具链）：
moon build cmd/main --target native
```
