// Structured validation errors produced by MoonCheck.
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
  /// A number is smaller than its `min`.
  BelowMinimum
  /// A number is larger than its `max`.
  AboveMaximum
  /// A string / array is shorter than its `min_length`.
  TooShort
  /// A string / array is longer than its `max_length`.
  TooLong
  /// The value is not one of the allowed `enum` values.
  NotInEnum
  /// A number is not finite (`NaN`, `infinity`).
  InvalidNumber
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
  /// Human-readable description, e.g. `expected Int, got String`.
  message : String
} derive(Eq, @debug.Debug)

///|
/// Render one error as a single line: `$.user.age: expected Int, got String`.
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
    InvalidNumber => "invalid_number"
    InvalidJson => "invalid_json"
  }
}
