# MoonCheck

[![CI](https://github.com/sgy1023-crt/MoonCheck/actions/workflows/ci.yml/badge.svg)](https://github.com/sgy1023-crt/MoonCheck/actions/workflows/ci.yml)
[![mooncakes](https://img.shields.io/badge/mooncakes-sgy1023--crt%2FMoonCheck-blue)](https://mooncakes.io/docs/sgy1023-crt/MoonCheck)

**A batch / CI command line front end for JSON Schema validation in MoonBit,
built on [mizchi/jsonschema](https://github.com/mizchi/moonbit_jsonschema).**

> **Attribution.** MoonCheck does **not** implement a JSON Schema validator.
> All schema compilation and data validation is done by
> [`mizchi/jsonschema`](https://mooncakes.io/docs/mizchi/jsonschema) (MIT),
> declared as a dependency in `moon.mod`. MoonCheck is an extension on top of
> it that adds what you need to run schema checks over many files in CI.
> Versions up to 0.1.0 shipped their own small validation engine; from 0.2.0
> that engine was removed and replaced by `mizchi/jsonschema`.

## What MoonCheck adds on top of mizchi/jsonschema

| | mizchi/jsonschema | MoonCheck adds |
|---|---|---|
| Validate a value against a JSON Schema | ✅ (the engine) | uses it as is |
| Command line tool | – | `mooncheck validate schema.json data/*.json` |
| Many documents in one run, one bad file does not stop the run | – | ✅ |
| Machine-readable report for CI | – | `--report json`, stable error kinds |
| Stable exit codes | – | `0` valid / `1` invalid data / `2` usage, I/O or schema error |
| Schema linting | lenient: unknown nodes become "accept anything" | `check-schema` rejects typos such as `"type": "int"`, `"min"`, `"required": true` with a location and a hint |
| Error format | `JsonPointer` + message tree | flat errors with `$.user.tags[0]` paths and a `kind` (`missing_required`, `type_mismatch`, `above_max`, …) |

The schema linter matters in CI: a schema with a typo would otherwise compile
to an accept-all validator, and every document would silently pass.

## Installation / Build

Requires the [MoonBit toolchain](https://www.moonbitlang.com/download/).

```bash
moon update                        # refresh the registry index
moon check                         # type-check
moon test                          # run the test suite
moon run examples/demo             # run the demo (any backend)
moon build cmd/main --target native   # build the `mooncheck` executable
```

The library runs on any backend. The `cmd/main` CLI targets **native** builds
(MSVC on Windows, a C toolchain on Linux/macOS).

## CLI Usage

Schemas are standard JSON Schema documents:

```json
{
  "type": "object",
  "required": ["host", "port"],
  "properties": {
    "host":    { "type": "string", "minLength": 1 },
    "port":    { "type": "integer", "minimum": 1, "maximum": 65535 },
    "debug":   { "type": "boolean" },
    "timeout": { "type": "integer", "minimum": 0, "maximum": 600 }
  }
}
```

Validate many documents at once (the shell expands the glob):

```bash
mooncheck validate examples/cli/config.schema.json examples/cli/configs/*.json
```

```
ok: examples/cli/configs/service_a.json
ok: examples/cli/configs/service_b.json
examples/cli/configs/service_c_broken.json: $.host: String length 0 is less than minimum 1
examples/cli/configs/service_c_broken.json: $.port: Value is greater than maximum 65535
examples/cli/configs/service_c_broken.json: $.timeout: Value is not a number
checked 3 document(s): 2 ok, 1 failed, 3 error(s)
error: 1 of 3 document(s) failed validation
```

The messages come from `mizchi/jsonschema`; the paths, grouping, summary and
exit code come from MoonCheck.

Add `--report json` for a report a CI job or script can consume:

```json
{
  "schema": "examples/cli/config.schema.json",
  "ok": false,
  "summary": { "checked": 3, "failed": 1, "errors": 3 },
  "documents": [
    { "path": "examples/cli/configs/service_a.json", "ok": true, "errors": [] },
    { "path": "examples/cli/configs/service_b.json", "ok": true, "errors": [] },
    {
      "path": "examples/cli/configs/service_c_broken.json",
      "ok": false,
      "errors": [
        { "path": "$.host", "kind": "too_short", "message": "String length 0 is less than minimum 1" },
        { "path": "$.port", "kind": "above_max", "message": "Value is greater than maximum 65535" },
        { "path": "$.timeout", "kind": "type_mismatch", "message": "Value is not a number" }
      ]
    }
  ]
}
```

Lint a schema before using it:

```bash
mooncheck check-schema bad.schema.json
```

```
error: invalid schema "bad.schema.json": #/required: must be an array of property names, e.g. ["name"]; #/properties/age/type: unknown type "int" (did you mean "integer"?); #/properties/age: unknown keyword "min" (did you mean "minimum"?)
```

Other options: `-q/--quiet` (only failures), `-h/--help`, `-V/--version`.

Exit codes: `0` every document is valid, `1` at least one document is invalid,
`2` usage, I/O or schema error.

### Error kinds

| kind | produced by |
|---|---|
| `missing_required` | `required` |
| `type_mismatch` | `type` |
| `below_min` / `above_max` | `minimum`, `exclusiveMinimum` / `maximum`, `exclusiveMaximum` |
| `too_short` / `too_long` | `minLength`, `minItems` / `maxLength`, `maxItems` |
| `not_in_enum` | `enum` |
| `constraint` | any other keyword (`const`, `anyOf`, `additionalProperties`, …) |
| `invalid_json` | the data file is not JSON |

## Library Usage

```moonbit
match @MoonCheck.validate_strings(schema_text, data_text) {
  Ok(errors) if errors.is_empty() => println("valid")
  Ok(errors) => for error in errors { println(@MoonCheck.to_string(error)) }
  Err(reason) => println("could not validate: \{reason}")
}
```

Batch reports, the same path the CLI takes:

```moonbit
let schema = match @MoonCheck.parse_schema_text(schema_text) {
  Ok(schema) => schema
  Err(reason) => panic()
}
let report = @MoonCheck.RunReport::new("schema.json", [
  @MoonCheck.FileResult::new("a.json", @MoonCheck.validate_text(schema, text_a)),
  @MoonCheck.FileResult::new("b.json", @MoonCheck.validate_text(schema, text_b)),
])
println(@MoonCheck.render(report, @MoonCheck.ReportFormat::json(), false))
```

`@MoonCheck.lint_schema(json)` returns the linter's findings as a list.

## Scope

Which JSON Schema keywords are supported is decided by `mizchi/jsonschema`;
MoonCheck does not re-implement or extend the validation rules. The linter
rejects `"type": [..]` unions (use `anyOf`) because the underlying validator
would ignore them.

Related MoonBit projects: [mizchi/jsonschema](https://github.com/mizchi/moonbit_jsonschema)
(the engine MoonCheck builds on) and [Betterlol/moon_zod](https://github.com/Betterlol/moon_zod)
(Zod-style in-code schemas for LLM tool calling). MoonCheck does not compete
with either: it is a CLI/CI layer, not a validator.

## Testing

```bash
moon test
```

41 tests: the schema linter, the error adapter (paths and kinds for every
keyword), CLI argument parsing, the batch flow and both report formats.

## Project Structure

```
MoonCheck/
├── moon.mod                 # module metadata, depends on mizchi/jsonschema
├── schema.mbt               # schema linter + compile via mizchi/jsonschema
├── validate.mbt             # adapter: mizchi/jsonschema errors -> MoonCheck errors
├── error.mbt                # stable ValidationError / ErrorKind
├── report.mbt               # text and JSON reports
├── cli.mbt                  # command line parsing + usage text
├── *_test.mbt, *_wbtest.mbt # tests
├── cmd/main/                # CLI shell: reads files, prints, sets exit status
└── examples/
    ├── demo/                # runnable demo (moon run examples/demo)
    └── cli/                 # sample schemas + data (configs/ for batch runs)
```

## License

Apache-2.0. Depends on [mizchi/jsonschema](https://github.com/mizchi/moonbit_jsonschema) (MIT).
