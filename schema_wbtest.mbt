// Tests for the schema linter and for the adapter that maps
// `mizchi/jsonschema` errors to MoonCheck's paths and kinds.

///|
fn must_parse(schema : Json) -> Schema {
  parse_schema(schema) catch {
    SchemaError::InvalidSchema(msg) => abort("schema should parse: \{msg}")
  }
}

///|
fn kinds(schema : Json, value : Json) -> Array[(String, ErrorKind)] {
  validate(must_parse(schema), value).map(e => (e.path, e.kind))
}

///|
test "lint: a standard schema is clean" {
  let schema : Json = {
    "type": "object",
    "required": ["id"],
    "properties": {
      "id": { "type": "integer", "minimum": 1 },
      "tags": { "type": "array", "items": { "type": "string" }, "maxItems": 3 },
      "mode": { "anyOf": [{ "type": "string" }, { "type": "null" }] },
    },
  }
  assert_eq(lint_schema(schema), [])
}

///|
test "lint: typos are reported with a hint and a location" {
  let schema : Json = {
    "type": "object",
    "properties": {
      "age": { "type": "int", "min": 0 },
      "ok": { "type": "bool" },
    },
  }
  let problems = lint_schema(schema)
  assert_true(
    problems.contains(
      "#/properties/age/type: unknown type \"int\" (did you mean \"integer\"?)",
    ),
  )
  assert_true(
    problems.contains(
      "#/properties/age: unknown keyword \"min\" (did you mean \"minimum\"?)",
    ),
  )
  assert_true(
    problems.contains(
      "#/properties/ok/type: unknown type \"bool\" (did you mean \"boolean\"?)",
    ),
  )
}

///|
test "lint: malformed keywords" {
  let schema : Json = {
    "type": ["string", "null"],
    "required": true,
    "minLength": -1,
    "maximum": "10",
    "enum": "a",
    "items": 3,
  }
  let problems = lint_schema(schema)
  assert_eq(problems.length(), 6)
}

///|
test "lint: nested schemas in anyOf and $defs are checked" {
  let schema : Json = {
    "anyOf": [{ "type": "string" }, { "type": "float" }],
    "$defs": { "x": { "type": "nope" } },
  }
  assert_eq(lint_schema(schema), [
    "#/anyOf/1/type: unknown type \"float\"", "#/$defs/x/type: unknown type \"nope\"",
  ])
}

///|
test "parse_schema refuses what the linter reports" {
  let caught = try {
    let _ = parse_schema({ "type": "object", "properties": [] })
    false
  } catch {
    SchemaError::InvalidSchema(msg) => {
      assert_true(msg.contains("#/properties: must be an object"))
      true
    }
  }
  assert_true(caught)
}

///|
test "adapter: paths use $.field and [index]" {
  let schema : Json = {
    "type": "object",
    "properties": {
      "user": {
        "type": "object",
        "properties": {
          "tags": { "type": "array", "items": { "type": "string" } },
        },
      },
    },
  }
  assert_eq(kinds(schema, { "user": { "tags": ["a", 1] } }), [
    ("$.user.tags[1]", Type),
  ])
}

///|
test "adapter: every keyword maps to a stable kind" {
  let schema : Json = {
    "type": "object",
    "required": ["id"],
    "properties": {
      "low": { "type": "number", "minimum": 0 },
      "high": { "type": "integer", "maximum": 9 },
      "short": { "type": "string", "minLength": 2 },
      "long": { "type": "array", "items": { "type": "integer" }, "maxItems": 1 },
      "color": { "type": "string", "enum": ["red"] },
      "fixed": { "const": 1 },
    },
  }
  let got = kinds(schema, {
    "low": -1,
    "high": 10,
    "short": "a",
    "long": [1, 2],
    "color": "blue",
    "fixed": 2,
  })
  for
    expected in [
      ("$.id", MissingRequired),
      ("$.low", BelowMinimum),
      ("$.high", AboveMaximum),
      ("$.short", TooShort),
      ("$.long", TooLong),
      ("$.color", NotInEnum),
      ("$.fixed", Constraint),
    ] {
    assert_true(got.contains(expected))
  }
  assert_eq(got.length(), 7)
}

///|
test "adapter: a bare enum node is NotInEnum, a type error is Type" {
  assert_eq(kinds({ "enum": [1, 2] }, 3), [("$", NotInEnum)])
  assert_eq(kinds({ "type": "integer" }, 1.5), [("$", Type)])
  assert_eq(kinds({ "type": "boolean" }, "yes"), [("$", Type)])
}

///|
test "adapter: a valid document has no errors" {
  let schema = must_parse({ "type": "string", "maxLength": 3 })
  assert_true(is_valid(schema, "abc"))
}
