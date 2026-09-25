// Validation, delegated to `mizchi/jsonschema`.
//
// This file is an adapter: `mizchi/jsonschema` does the schema checking, and
// MoonCheck maps each of its errors to a flat `ValidationError` with a
// `$.a[0]`-style path and a stable `ErrorKind`, which is what the reports and
// exit codes are built on.

///|
/// Validate a JSON value against a schema.
///
/// Returns all validation errors. An empty array means the value is valid.
pub fn validate(schema : Schema, value : Json) -> Array[ValidationError] {
  match schema.validator.validate(value) {
    Ok(_) => []
    Err(errors) => errors.map(convert)
  }
}

///|
/// Convenience: `true` when `validate` finds no error.
pub fn is_valid(schema : Schema, value : Json) -> Bool {
  validate(schema, value).is_empty()
}

///|
/// Validate in one step from raw text.
///
/// Takes a schema document and a data document, both as JSON text.
/// Returns `Ok(errors)` where an empty list means the data is valid, or
/// `Err(reason)` when either document could not be parsed.
pub fn validate_strings(
  schema_text : String,
  data_text : String,
) -> Result[Array[ValidationError], String] {
  let schema = parse_schema_string(schema_text) catch {
    SchemaError::InvalidSchema(msg) => return Err("invalid schema: \{msg}")
  }
  let data = @json.parse(data_text) catch {
    err => return Err("data is not valid JSON: \{err}")
  }
  Ok(validate(schema, data))
}

///|
/// Parse a schema document, returning the reason as a string on failure.
///
/// Batch and CLI callers parse the schema once and reuse it for every data
/// document, so a broken schema is reported separately from data errors.
pub fn parse_schema_text(text : String) -> Result[Schema, String] {
  Ok(parse_schema_string(text)) catch {
    SchemaError::InvalidSchema(msg) => Err(msg)
  }
}

///|
/// Validate a data document against an already parsed schema.
///
/// Unlike `validate_strings`, a data document that is not valid JSON is
/// reported as a single `InvalidJson` error instead of aborting the call, so
/// callers that process many documents can keep going and report everything.
pub fn validate_text(
  schema : Schema,
  data_text : String,
) -> Array[ValidationError] {
  let data = @json.parse(data_text) catch {
    err =>
      return [
        {
          path: "$",
          kind: InvalidJson,
          message: "data is not valid JSON: \{err}",
        },
      ]
  }
  validate(schema, data)
}

///|
fn convert(error : @jsonschema.ValidationError) -> ValidationError {
  {
    path: data_path(error.json_path),
    kind: classify(error.schema_path, error.message),
    message: error.message,
  }
}

///|
/// Render a data pointer as `$`, `$.user.age` or `$.tags[0]`.
fn data_path(pointer : @jsonschema.JsonPointer) -> String {
  match pointer {
    Root => "$"
    Key(parent, key~) => "\{data_path(parent)}.\{key}"
    Index(parent, index~) => "\{data_path(parent)}[\{index}]"
  }
}

///|
/// Classify an error by the schema keyword that produced it.
///
/// `mizchi/jsonschema` points `schema_path` at the failing keyword (for
/// example `#/properties/age/minimum`). Errors raised by a whole schema node
/// (wrong type, a bare `enum`, `const`) point at the node itself instead, so
/// those are told apart by their message.
fn classify(
  schema_path : @jsonschema.JsonPointer,
  message : String,
) -> ErrorKind {
  if is_node(schema_path) {
    return if message.has_prefix("Value does not match constant") ||
      message.has_prefix("Failed to resolve") ||
      message.has_prefix("Array does not have item") {
      Constraint
    } else if message.contains(" is not in ") {
      NotInEnum
    } else {
      Type
    }
  }
  match schema_path {
    Key(_, key="required") => MissingRequired
    Key(_, key="minimum") | Key(_, key="exclusiveMinimum") => BelowMinimum
    Key(_, key="maximum") | Key(_, key="exclusiveMaximum") => AboveMaximum
    Key(_, key="minLength") | Key(_, key="minItems") => TooShort
    Key(_, key="maxLength") | Key(_, key="maxItems") => TooLong
    Key(_, key="enum") => NotInEnum
    _ => Constraint
  }
}

///|
/// `true` when `schema_path` points at a schema node rather than a keyword.
fn is_node(schema_path : @jsonschema.JsonPointer) -> Bool {
  match schema_path {
    Root => true
    Key(Key(_, key="properties"), ..) => true
    Key(_, key="items") | Key(_, key="$ref") => true
    Index(_, ..) => true
    _ => false
  }
}
