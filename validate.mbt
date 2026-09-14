// The MoonCheck validation engine.
//
// `validate` walks a JSON value against a schema, collecting every problem it
// finds (rather than stopping at the first). Errors are reported in the order
// the schema declares things, so results are deterministic.

///|
/// Validate a JSON value against a schema.
///
/// Returns all validation errors. An empty array means the value is valid.
/// Undeclared fields of an object are ignored.
pub fn validate(schema : Type, value : Json) -> Array[ValidationError] {
  let out : Array[ValidationError] = []
  check(schema, value, "$", out)
  return out
}

///|
/// Convenience: `true` when `validate` finds no error.
pub fn is_valid(schema : Type, value : Json) -> Bool {
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
  return Ok(validate(schema, data))
}

///|
/// Parse a schema document, returning the reason as a string on failure.
///
/// Batch and CLI callers parse the schema once and reuse it for every data
/// document, so a broken schema is reported separately from data errors.
pub fn parse_schema_text(text : String) -> Result[Type, String] {
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
  schema : Type,
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
  return validate(schema, data)
}

///|
fn check(
  typ : Type,
  value : Json,
  path : String,
  out : Array[ValidationError],
) -> Unit {
  match typ {
    Str(spec) => check_string(spec, value, path, out)
    Num(spec) => check_numeric(spec, value, path, out, false)
    Int(spec) => check_numeric(spec, value, path, out, true)
    Bool => check_bool(value, path, out)
    Obj(spec) => check_object(spec, value, path, out)
    Arr(spec) => check_array(spec, value, path, out)
  }
}

///|
fn check_string(
  spec : StrSpec,
  value : Json,
  path : String,
  out : Array[ValidationError],
) -> Unit {
  match value {
    String(s) => {
      let len = s.char_length()
      if spec.min_length is Some(m) && len < m {
        out.push({
          path,
          kind: TooShort,
          message: "length must be at least \{m}, got \{len}",
        })
      }
      if spec.max_length is Some(m) && len > m {
        out.push({
          path,
          kind: TooLong,
          message: "length must be at most \{m}, got \{len}",
        })
      }
    }
    _ => push_type_error(path, "String", value, out)
  }
}

///|
fn check_numeric(
  spec : NumSpec,
  value : Json,
  path : String,
  out : Array[ValidationError],
  integer_only : Bool,
) -> Unit {
  match value {
    Number(n, ..) => {
      if !is_finite(n) {
        out.push({
          path,
          kind: InvalidNumber,
          message: "number must be finite",
        })
        return
      }
      if integer_only && !is_integer(n) {
        push_type_error(path, "Int", value, out)
        return
      }
      if spec.min is Some(m) && n < m {
        out.push({
          path,
          kind: BelowMinimum,
          message: "value must be at least \{fmt_num(m)}, got \{fmt_num(n)}",
        })
      }
      if spec.max is Some(m) && n > m {
        out.push({
          path,
          kind: AboveMaximum,
          message: "value must be at most \{fmt_num(m)}, got \{fmt_num(n)}",
        })
      }
    }
    _ => {
      let expected = if integer_only { "Int" } else { "Number" }
      push_type_error(path, expected, value, out)
    }
  }
}

///|
fn check_bool(
  value : Json,
  path : String,
  out : Array[ValidationError],
) -> Unit {
  match value {
    True | False => ()
    _ => push_type_error(path, "Bool", value, out)
  }
}

///|
fn check_object(
  spec : ObjSpec,
  value : Json,
  path : String,
  out : Array[ValidationError],
) -> Unit {
  match value {
    Object(members) =>
      for (name, prop) in spec.properties {
        let field_path = child_path(path, name)
        match members.get(name) {
          None =>
            if prop.required {
              out.push({
                path: field_path,
                kind: MissingRequired,
                message: "required field is missing",
              })
            }
          Some(field_value) => {
            check(prop.typ, field_value, field_path, out)
            if prop.enums is Some(allowed) && !in_list(allowed, field_value) {
              let list = Json::array(allowed).stringify()
              out.push({
                path: field_path,
                kind: NotInEnum,
                message: "value must be one of \{list}",
              })
            }
          }
        }
      }
    _ => push_type_error(path, "Object", value, out)
  }
}

///|
fn check_array(
  spec : ArrSpec,
  value : Json,
  path : String,
  out : Array[ValidationError],
) -> Unit {
  match value {
    Array(items) => {
      let len = items.length()
      if spec.min_length is Some(m) && len < m {
        out.push({
          path,
          kind: TooShort,
          message: "length must be at least \{m}, got \{len}",
        })
      }
      if spec.max_length is Some(m) && len > m {
        out.push({
          path,
          kind: TooLong,
          message: "length must be at most \{m}, got \{len}",
        })
      }
      for i in 0..<len {
        check(spec.item, items[i], "\{path}[\{i}]", out)
      }
    }
    _ => push_type_error(path, "Array", value, out)
  }
}

///|
fn push_type_error(
  path : String,
  expected : String,
  value : Json,
  out : Array[ValidationError],
) -> Unit {
  let got = value_name(value)
  out.push({ path, kind: Type, message: "expected \{expected}, got \{got}", })
}

///|
fn child_path(path : String, name : String) -> String {
  if path == "$" {
    "$.\{name}"
  } else {
    "\{path}.\{name}"
  }
}

///|
/// Element-wise membership test (requires `Json` equality).
fn in_list(values : Array[Json], value : Json) -> Bool {
  for v in values {
    if v == value {
      return true
    }
  }
  return false
}

///|
fn is_finite(n : Double) -> Bool {
  !n.is_nan() && n != @double.infinity && n != @double.neg_infinity
}

///|
/// `true` when `n` is an integer-valued finite double (no fractional part).
fn is_integer(n : Double) -> Bool {
  is_finite(n) && n == @double.floor(n)
}

///|
/// Format a double for error messages without a trailing `.0` on whole numbers
/// that fit in an `Int64`.
fn fmt_num(n : Double) -> String {
  if n.is_nan() {
    return "NaN"
  }
  if n == @double.infinity {
    return "infinity"
  }
  if n == @double.neg_infinity {
    return "-infinity"
  }
  let whole = n.to_int64()
  if n == whole.to_double() {
    return whole.to_string()
  }
  return n.to_string()
}
