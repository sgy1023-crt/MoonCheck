// The command line contract of the `mooncheck` executable.
//
// Parsing lives in the library rather than in `cmd/main` on purpose: it is
// pure, so it is unit tested on every backend, while the executable stays a
// thin I/O shell that only reads files, prints the rendered report and sets
// the exit status.

///|
/// Options of the `validate` subcommand.
pub struct ValidateOptions {
  /// Output format for the report.
  format : ReportFormat
  /// Only report failures.
  quiet : Bool
  /// Path of the schema document.
  schema : String
  /// Paths of the data documents, in order.
  data : Array[String]
} derive(Eq, @debug.Debug)

///|
/// Options of the `check-schema` subcommand.
pub struct CheckSchemaOptions {
  /// Path of the schema document.
  path : String
} derive(Eq, @debug.Debug)

///|
/// A parsed command line.
pub enum CliCommand {
  /// `--help`
  Help
  /// `--version`
  Version
  /// Validate one schema against one or more data documents.
  Validate(ValidateOptions)
  /// Check that a schema document is well formed.
  CheckSchema(CheckSchemaOptions)
  /// The command line could not be understood; carries the reason.
  Invalid(String)
} derive(Eq, @debug.Debug)

///|
/// Parse a command line (without the program name).
///
/// `validate` is optional, so `mooncheck validate s.json d.json` and
/// `mooncheck s.json d.json` are equivalent. Data paths may be given in any
/// number; shells expand globs, so `mooncheck s.json cfg/*.json` works without
/// any glob support in the CLI itself.
pub fn parse_args(argv : ArrayView[String]) -> CliCommand {
  if argv.length() == 0 {
    return Invalid("expected a schema file and at least one data file")
  }
  let first = argv[0]
  if first == "--help" || first == "-h" {
    return Help
  }
  if first == "--version" || first == "-V" {
    return Version
  }
  if first == "check-schema" {
    if argv.length() != 2 {
      return Invalid("check-schema takes exactly one schema file")
    }
    return CheckSchema({ path: argv[1], })
  }
  let mut format = Text
  let mut quiet = false
  let paths : Array[String] = []
  let mut i = if first == "validate" { 1 } else { 0 }
  while i < argv.length() {
    let arg = argv[i]
    if arg == "--report" {
      if i + 1 >= argv.length() {
        return Invalid("--report expects a value: text or json")
      }
      let value = argv[i + 1]
      if value == "json" {
        format = Json
      } else if value == "text" {
        format = Text
      } else {
        return Invalid("--report expects text or json, got \"\{value}\"")
      }
      i = i + 2
      continue
    }
    if arg == "--quiet" || arg == "-q" {
      quiet = true
      i = i + 1
      continue
    }
    if arg.has_prefix("-") && arg != "-" {
      return Invalid("unknown option: \{arg}")
    }
    paths.push(arg)
    i = i + 1
  }
  if paths.length() < 2 {
    return Invalid("expected a schema file and at least one data file")
  }
  let data : Array[String] = []
  let mut j = 1
  while j < paths.length() {
    data.push(paths[j])
    j = j + 1
  }
  return Validate({ format, quiet, schema: paths[0], data, })
}

///|
/// Usage text, printed by `--help` and after a usage error.
pub fn usage_text() -> String {
  let text =
    #|MoonCheck - validate JSON documents against a lightweight schema
    #|
    #|Usage:
    #|  mooncheck validate <schema.json> <data.json> [more.json ...]
    #|  mooncheck check-schema <schema.json>
    #|
    #|The `validate` subcommand is optional. Data paths may be repeated, and
    #|shells expand globs, so this works for CI:
    #|  mooncheck validate schema.json configs/*.json
    #|
    #|Options:
    #|  --report text|json   Report format (default: text)
    #|  -q, --quiet          Only report failures
    #|  -h, --help           Show this help
    #|  -V, --version        Show version
    #|
    #|Exit codes:
    #|  0  every document is valid
    #|  1  at least one document is invalid
    #|  2  usage, I/O or schema error
  return text
}

///|
/// Version text, printed by `--version`.
pub fn version_text() -> String {
  return "mooncheck 0.1.0"
}
