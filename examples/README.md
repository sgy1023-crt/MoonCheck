# Examples

## Runnable library demo (`demo/`)

A small program that validates three example payloads end to end and prints a
report for each: a REST API request, a JSON config file, and an AI tool call.

```bash
moon run examples/demo
```

## CLI sample files (`cli/`)

Files for trying the native CLI.

```bash
moon build cmd/main --target native
```

### One document at a time

```bash
# tool call, valid: prints nothing, exits 0
mooncheck validate examples/cli/schema.json examples/cli/data_valid.json

# tool call, invalid: prints the errors, exits 1
mooncheck validate examples/cli/schema.json examples/cli/data_invalid.json
```

### Batch mode (what CI uses)

`config.schema.json` describes a service config; `configs/` holds three of
them, one of which is broken on purpose.

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

Add `--report json` to get the same information as a machine-readable report,
and `-q` to print failures only.

### Lint a schema on its own

```bash
mooncheck check-schema examples/cli/config.schema.json
```
