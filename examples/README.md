# Examples

## Runnable library demo (`demo/`)

A small program that validates three example payloads end to end and prints a
report for each: a REST API request, a JSON config file, and an AI tool call.

```bash
moon run examples/demo
```

## CLI sample files (`cli/`)

Files for trying the native CLI:

```bash
moon build cmd/main --target native
# the built executable is reported by moon; then, from the repo root:

mooncheck validate examples/cli/schema.json examples/cli/data_valid.json     # exits 0
mooncheck validate examples/cli/schema.json examples/cli/data_invalid.json  # exits 1, prints errors
```

`schema.json` describes a tool call (`action`, `x`, `y`, optional `text`).
`data_valid.json` matches it; `data_invalid.json` violates the `action` enum,
`x >= 0` and `y <= 1080`.
