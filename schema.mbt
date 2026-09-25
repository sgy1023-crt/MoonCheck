// Loading and linting JSON Schema documents.
//
// `mizchi/jsonschema` compiles a schema into a validator. Like many
// validators it is lenient: a node it does not recognise (a typo such as
// `"type": "int"`, a `"type": ["string", "null"]` union, or a misspelt keyword
// such as `"min"`) silently becomes "accept anything". In CI that is the worst
// failure mode: a broken contract makes every document pass.
//
// MoonCheck therefore lints the schema document before compiling it and
// refuses schemas whose meaning would be lost. `mooncheck check-schema` exposes
// the same linter on its own.

///|
/// Raised when a schema document is malformed.
pub(all) suberror SchemaError {
  /// Human-readable description of what is wrong.
  InvalidSchema(String)
} derive(Eq, @debug.Debug)

///|
/// A compiled schema, ready to validate documents.
pub struct Schema {
  priv validator : @jsonschema.Validator
}

///|
/// Type names understood by the underlying validator.
let known_types : Array[String] = [
  "null", "boolean", "string", "number", "integer", "array", "object",
]

///|
/// Keywords that look plausible but are ignored by JSON Schema, with the
/// keyword that was most likely meant.
let misspelt_keywords : Array[(String, String)] = [
  ("min", "minimum"),
  ("max", "maximum"),
  ("minlength", "minLength"),
  ("maxlength", "maxLength"),
  ("minitems", "minItems"),
  ("maxitems", "maxItems"),
  ("item", "items"),
  ("property", "properties"),
  ("enums", "enum"),
]

///|
/// Lint a schema document.
///
/// Returns every problem found, each prefixed with the JSON pointer of the
/// offending schema node (`#/properties/age`). An empty array means the schema
/// is safe to compile.
pub fn lint_schema(schema : Json) -> Array[String] {
  let out : Array[String] = []
  lint_node(schema, "#", out)
  out
}

///|
/// Lint and compile a schema document.
pub fn parse_schema(json : Json) -> Schema raise SchemaError {
  let problems = lint_schema(json)
  if !problems.is_empty() {
    raise SchemaError::InvalidSchema(problems.join("; "))
  }
  let validator = @jsonschema.build_validator(json) catch {
    err => raise SchemaError::InvalidSchema("cannot compile schema: \{err}")
  }
  { validator, }
}

///|
/// Lint and compile a schema from JSON text.
pub fn parse_schema_string(input : String) -> Schema raise SchemaError {
  let json = @json.parse(input) catch {
    err => raise SchemaError::InvalidSchema("invalid JSON in schema: \{err}")
  }
  parse_schema(json)
}

///|
fn lint_node(node : Json, at : String, out : Array[String]) -> Unit {
  guard node is Object(members) else {
    out.push("\{at}: a schema must be a JSON object")
    return
  }
  match members.get("type") {
    None => ()
    Some(String(t)) =>
      if !known_types.contains(t) {
        let hint = match t {
          "int" => " (did you mean \"integer\"?)"
          "bool" => " (did you mean \"boolean\"?)"
          _ => ""
        }
        out.push("\{at}/type: unknown type \"\{t}\"\{hint}")
      }
    Some(Array(_)) =>
      out.push("\{at}/type: type unions are not supported, use \"anyOf\"")
    Some(_) => out.push("\{at}/type: must be a string")
  }
  for pair in misspelt_keywords {
    let (wrong, right) = pair
    if members.contains(wrong) {
      out.push(
        "\{at}: unknown keyword \"\{wrong}\" (did you mean \"\{right}\"?)",
      )
    }
  }
  for key in ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum"] {
    if members.get(key) is Some(v) && !(v is Number(_, ..)) {
      out.push("\{at}/\{key}: must be a number")
    }
  }
  for key in ["minLength", "maxLength", "minItems", "maxItems"] {
    match members.get(key) {
      None => ()
      Some(Number(n, ..)) if n >= 0.0 && n == n.to_int().to_double() => ()
      Some(_) => out.push("\{at}/\{key}: must be a non-negative integer")
    }
  }
  match members.get("required") {
    None => ()
    Some(Array(names)) =>
      if !names.iter().all(name => name is String(_)) {
        out.push("\{at}/required: must list property names as strings")
      }
    Some(_) =>
      out.push(
        "\{at}/required: must be an array of property names, e.g. [\"name\"]",
      )
  }
  if members.get("enum") is Some(v) && !(v is Array(_)) {
    out.push("\{at}/enum: must be an array")
  }
  match members.get("properties") {
    None => ()
    Some(Object(props)) =>
      for name, sub in props {
        lint_node(sub, "\{at}/properties/\{name}", out)
      }
    Some(_) => out.push("\{at}/properties: must be an object")
  }
  match members.get("items") {
    None | Some(True) | Some(False) => ()
    Some(sub) => lint_node(sub, "\{at}/items", out)
  }
  for key in ["anyOf", "allOf", "oneOf"] {
    match members.get(key) {
      None => ()
      Some(Array(subs)) =>
        for i, sub in subs {
          lint_node(sub, "\{at}/\{key}/\{i}", out)
        }
      Some(_) => out.push("\{at}/\{key}: must be an array of schemas")
    }
  }
  for key in ["$defs", "definitions"] {
    if members.get(key) is Some(Object(defs)) {
      for name, sub in defs {
        lint_node(sub, "\{at}/\{key}/\{name}", out)
      }
    }
  }
}
