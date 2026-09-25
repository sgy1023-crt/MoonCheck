// Structured validation errors produced by MoonCheck.
//
// These are a stable, flat view over the errors of `mizchi/jsonschema`, so the
// reports and exit codes do not depend on its internal error shape.
//
// Validation collects *all* problems it finds instead of stopping at the first
// one. Every error carries:
//   - the JSON pointer-like path of the offending value (e.g. `$.user.age`)
//   - a machine-readable kind
//   - a human-readable reason

///|
/// Classification of a single validation problem.
pub enum ErrorKind {
  /// A `required` field is absent from the object.
  MissingRequired
  /// The value has the wrong JSON type.
  Type
  /// A number is smaller than its `minimum` / `exclusiveMinimum`.
  BelowMinimum
  /// A number is larger than its `maximum` / `exclusiveMaximum`.
  AboveMaximum
  /// A string / array is shorter than its `minLength` / `minItems`.
  TooShort
  /// A string / array is longer than its `maxLength` / `maxItems`.
  TooLong
  /// The value is not one of the allowed `enum` values.
  NotInEnum
  /// Any other JSON Schema keyword failed (`const`, `anyOf`,
  /// `additionalProperties`, ...).
  Constraint
  /// The data document could not be parsed as JSON at all. Used by batch and
  /// file-oriented callers so one bad document does not abort the whole run.
  InvalidJson
} derive(Eq, @debug.Debug)

///|
/// A single validation error.
pub struct ValidationError {
  /// Path of the offending value, e.g. `$.user.age` or `$.tags[0]`.
  path : String
  /// Machine-readable classification.
  kind : ErrorKind
  /// Human-readable description, e.g. `Value is not a string`.
  message : String
} derive(Eq, @debug.Debug)

///|
/// Render one error as a single line: `$.user.age: Value is not a number`.
pub fn to_string(error : ValidationError) -> String {
  "\{error.path}: \{error.message}"
}

///|
/// Stable, machine-readable name of an error kind.
///
/// These strings are part of the JSON report format, so they are kept short,
/// lowercase and stable rather than being derived from the constructor names.
pub fn error_kind_name(kind : ErrorKind) -> String {
  match kind {
    MissingRequired => "missing_required"
    Type => "type_mismatch"
    BelowMinimum => "below_min"
    AboveMaximum => "above_max"
    TooShort => "too_short"
    TooLong => "too_long"
    NotInEnum => "not_in_enum"
    Constraint => "constraint"
    InvalidJson => "invalid_json"
  }
}
