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

The CLI validates a schema file and a data file:

```bash
# the leading `validate` subcommand is optional
mooncheck validate schema.json data.json
mooncheck validate examples/cli/schema.json examples/cli/data_valid.json
# -> valid: data matches the schema

mooncheck validate examples/cli/schema.json examples/cli/data_invalid.json
# -> $.action: value must be one of ["click","type","scroll"]
#    $.x: value must be at least 0, got -5
#    $.y: value must be at most 1080, got 5000
```

Exit codes: `0` data is valid, `1` data is invalid (errors are printed),
`2` usage or I/O error. `mooncheck --help` and `mooncheck --version` print
usage and version.

Because file I/O and native execution require the native backend, build the
executable as described under *Installation / Build*. The validation logic the
CLI runs is the library's `validate_strings`, covered by the test suite on
every backend.

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

## Project Structure

```
MoonCheck/
├── moon.mod                 # module metadata
├── moon.pkg                 # root library package
├── schema.mbt               # schema type model (Type, specs, props)
├── schema_json.mbt          # parse schema documents from JSON
├── validate.mbt             # the validation engine + validate_strings
├── error.mbt                # structured ValidationError / ErrorKind
├── MoonCheck_test.mbt       # black-box tests (public API)
├── MoonCheck_wbtest.mbt     # white-box tests (internals)
├── cmd/
│   └── main/                # CLI (native target)
└── examples/
    ├── demo/                # runnable demo (moon run examples/demo)
    └── cli/                 # sample schema + data files for the CLI
```

## License

Apache-2.0
