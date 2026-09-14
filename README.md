# MoonCheck

A lightweight, reusable JSON / API parameter validator with a CLI, written in MoonBit.

MoonCheck validates JSON data against a small, hand-written schema and reports
**all** problems it finds as clear, human-readable errors. It is a general
purpose developer tool: validate REST API request bodies, JSON config files, or
AI agent tool-call arguments before you trust them.

## Features

- Small schema language with the kinds you actually use:
  `string`, `number`, `int`, `bool`, `object`, `array`
- Constraints: `required`, `enum`, numeric `min`/`max`,
  `minLength`/`maxLength` for strings, `minItems`/`maxItems` for arrays,
  `items` for array element types, and arbitrarily **nested objects**
- Structured errors: every error carries a JSON-pointer-like **path**
  (`$.user.age`, `$.tags[0]`), a machine-readable kind, and a human message
  such as `expected Int, got String`
- Collects **all** errors instead of stopping at the first
- **Built for CI**: validate many documents in one run, with a machine-readable
  JSON report (`--report json`) and stable exit codes
- **Schema linting**: `mooncheck check-schema schema.json` checks the schema
  document itself, so a broken contract fails before any data is checked
- Shell globs work as-is (`mooncheck validate s.json configs/*.json`); the CLI
  needs no glob support and no extra dependency
- Schemas are described as plain JSON documents, so they work across
  languages and are easy to read; they can also be built directly in MoonBit
- No runtime dependencies beyond the MoonBit standard library

## Installation / Build

Requires the [MoonBit toolchain](https://www.moonbitlang.com/download/).

```bash
moon check            # type-check the library and all packages
moon test             # run the test suite
moon run examples/demo   # run the demo (works on any backend)
```

The library part is pure MoonBit and runs on any backend. The `cmd/main` CLI
package targets **native** builds; building the native executable needs an
MSVC toolchain on Windows or a C toolchain on Linux/macOS:

```bash
# Windows (MSVC) or Linux/macOS
moon build cmd/main --target native
```

## Quick Start

Validate data from a schema document and a JSON string in one call:

```moonbit
match @MoonCheck.validate_strings(schema_text, data_text) {
  Ok(errors) if errors.is_empty() => println("valid")
  Ok(errors) =>
    for error in errors {
      println(@MoonCheck.to_string(error))
    }
  Err(reason) => println("could not validate: \{reason}")
}
```

Or parse a schema once and reuse it against parsed JSON values:

```moonbit
let schema = try { @MoonCheck.parse_schema_string(schema_text) } catch {
  _ => panic("bad schema")
}
let data = try { @json.parse(data_text) } catch { _ => panic("bad json") }
if @MoonCheck.is_valid(schema, data) { ... }
```

For batch work, parse the schema once, validate every document, and render one
report — the same path the CLI takes:

```moonbit
let results = [
  @MoonCheck.FileResult::new("a.json", @MoonCheck.validate_text(schema, text_a)),
  @MoonCheck.FileResult::new("b.json", @MoonCheck.validate_text(schema, text_b)),
]
let report = @MoonCheck.RunReport::new("schema.json", results)
println(@MoonCheck.render(report, @MoonCheck.ReportFormat::text(), false))
println(@MoonCheck.render(report, @MoonCheck.ReportFormat::json(), false))
```

## Schema Example

Schemas are JSON documents. This one describes a small user object:

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string", "required": true, "minLength": 1, "maxLength": 30 },
    "age":  { "type": "int", "required": true, "min": 0, "max": 150 },
    "role": { "type": "string", "required": false, "enum": ["admin", "user"] },
    "tags": { "type": "array", "required": false, "maxItems": 5, "items": { "type": "string" } }
  }
}
```

Supported `type` values: `string`, `number`, `int`, `bool`, `object`, `array`.

Supported keys:

| Key         | Applies to | Meaning                                    |
|-------------|------------|--------------------------------------------|
| `type`      | all        | The schema kind (required)                 |
| `required`  | property   | Property must be present (`true`)          |
| `enum`      | property   | Value must equal one of the listed literals|
| `min`/`max` | `int`, `number` | Inclusive numeric bounds               |
| `minLength`/`maxLength` | `string` | Character count bounds          |
| `minItems`/`maxItems` | `array` | Element count bounds              |
| `items`     | `array`    | Schema applied to every element (required) |
| `properties`| `object`   | Map of property name → property schema     |

Objects with `type: "object"` validate the declared `properties`; undeclared
fields are ignored. Properties are optional unless `required: true`.

## Validation Example

Given the schema above and this data:

```json
{ "name": "", "age": 200, "role": "owner", "tags": ["a", "b"] }
```

`validate_strings` returns four errors, printed one per line:

```
$.name: length must be at least 1, got 0
$.age: value must be at most 150, got 200
$.role: value must be one of ["admin","user"]
$.tags: length must be at most 5, got 4
```

`$.tags[0]` would be the path of an invalid array element, and
`$.user.email` the path of a field inside a nested object.

## CLI Usage

Build the executable first (see *Installation / Build*), then:

```bash
# one schema, one data file — valid: prints nothing, exits 0
mooncheck validate examples/cli/schema.json examples/cli/data_valid.json

# one schema, one data file — invalid: prints the errors, exits 1
mooncheck validate examples/cli/schema.json examples/cli/data_invalid.json
# -> $.action: value must be one of ["click","type","scroll"]
#    $.x: value must be at least 0, got -5
#    $.y: value must be at most 1080, got 5000
```

The part that is not just another validator is batch/CI mode: pass several
documents (the shell expands the glob) and each gets its own result, with a
summary at the end.

```bash
mooncheck validate examples/cli/config.schema.json examples/cli/configs/*.json
```

```
ok: service_a.json
ok: service_b.json
service_c_broken.json: $.host: length must be at least 1, got 0
service_c_broken.json: $.port: value must be at most 65535, got 70000
service_c_broken.json: $.timeout: expected Int, got String
checked 3 document(s): 2 ok, 1 failed, 3 error(s)
```

Add `--report json` for a machine-readable report that a CI job or a script can
consume directly:

```json
{
  "schema": "examples/cli/config.schema.json",
  "ok": false,
  "summary": { "checked": 3, "failed": 1, "errors": 3 },
  "documents": [
    { "path": "service_a.json", "ok": true, "errors": [] },
    { "path": "service_b.json", "ok": true, "errors": [] },
    {
      "path": "service_c_broken.json",
      "ok": false,
      "errors": [
        { "path": "$.host", "kind": "too_short", "message": "length must be at least 1, got 0" },
        { "path": "$.port", "kind": "above_max", "message": "value must be at most 65535, got 70000" },
        { "path": "$.timeout", "kind": "type_mismatch", "message": "expected Int, got String" }
      ]
    }
  ]
}
```

Other commands:

```bash
mooncheck check-schema schema.json   # lint a schema document on its own
mooncheck --help                     # usage
mooncheck --version                  # version
mooncheck validate s.json d.json -q  # only report failures
```

Exit codes: `0` every document is valid, `1` at least one document is invalid,
`2` usage, I/O or schema error.

The executable is a thin I/O shell: argument parsing, batch orchestration and
report rendering live in `cli.mbt` and `report.mbt` in the library, so they are
covered by the test suite on every backend. Only file reading and the process
exit status live in `cmd/main`.

## Use Cases

- **REST API request validation** — check `username`, `age`, `email` and
  friends on an incoming request before handing the payload to handlers.
- **Configuration file validation** — a tool reads a JSON config; MoonCheck
  verifies required keys, types, and ranges before the tool trusts it.
- **AI Agent / LLM tool-call validation** — a model emits a tool call such as
  `{ "action": "click", "x": 123, "y": 456 }`; validate fields, types, and
  ranges before dispatching to the executor.

The same core also serves: test-data sanity checks, mocked-API fixtures,
and any place a JSON payload must be trusted before it is used.

## Ecosystem and Scope

MoonBit already has JSON validation libraries, and this project does not try to
replace them. Where MoonCheck sits:

| Project | Focus | Interface |
|---|---|---|
| [Betterlol/moon_zod](https://github.com/Betterlol/moon_zod) | Zod/Pydantic-style runtime schemas for LLM tool calling: many kinds, combinators, strip/strict modes, JSON Schema export, prompt and struct-code generation | MoonBit code API; CLI that infers a schema from a sample |
| [mizchi/jsonschema](https://github.com/mizchi/moonbit_jsonschema) | JSON Schema (subset) validation plus MoonBit code generation | MoonBit code API |
| [YumeCross/schema](https://github.com/YumeCross/schema) | Lightweight JSON Schema validation | MoonBit code API |
| **MoonCheck** | A **schema-document-driven** validator for checks and automation: a small fixed schema language, all-error collection with precise paths, and a **batch/CI CLI** | JSON schema documents + MoonBit library + CLI |

**What this project deliberately does not do**: full JSON Schema Draft
compatibility (`$ref`, `anyOf`/`oneOf`, `pattern`, …), data transformation,
schema-to-code generation, prompt generation, or builder-style schema
combinators. Those are already covered by the projects above, and re-implementing
them would add surface without adding value.

**What it does instead**: schemas are plain JSON files that any language, tool
or pipeline can read and share; the CLI validates *many* documents in one run
and can emit either human-readable lines or a stable JSON report with documented
exit codes — the shape a CI job needs. The library has no dependencies beyond
the MoonBit standard library, and the implementation is small enough to read in
one sitting.

In short: for rich in-code schemas or LLM-oriented features, use moon_zod. For a
schema file that your CI, scripts and other languages can share, that is what
MoonCheck is for.

## Testing

```bash
moon test
```

The suite covers, for every kind, the normal path and each failure path:
valid strings / ints / bools / objects / arrays, required-field presence,
type mismatches, `min`/`max` bounds, string lengths, `enum` membership,
nested objects, and array element types (with paths such as `$.tags[0]`).
Schema-document parsing (valid and malformed) and end-to-end
`validate_strings` calls are also covered.

Command line parsing, the batch flow and both report renderings are tested as
well, which is why they live in the library rather than in the executable:
**69 tests, all green on the default backend.**

## Project Structure

```
MoonCheck/
├── moon.mod                 # module metadata
├── moon.pkg                 # root library package (no dependencies)
├── schema.mbt               # schema type model (Type, specs, props)
├── schema_json.mbt          # parse schema documents from JSON
├── validate.mbt             # validation engine, validate_strings/validate_text
├── error.mbt                # structured ValidationError / ErrorKind
├── report.mbt               # text and JSON reports
├── cli.mbt                  # command line parsing + usage text
├── MoonCheck_test.mbt       # black-box tests (public API)
├── MoonCheck_wbtest.mbt     # white-box tests (engine internals)
├── cli_wbtest.mbt           # white-box tests (CLI parsing + end-to-end flow)
├── report_wbtest.mbt        # white-box tests (report rendering)
├── cmd/
│   └── main/                # CLI shell: reads files, prints, sets exit status
└── examples/
    ├── demo/                # runnable demo (moon run examples/demo)
    └── cli/                 # sample schemas + data (configs/ for batch runs)
```

## License

Apache-2.0
