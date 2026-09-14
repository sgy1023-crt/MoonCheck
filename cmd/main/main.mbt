///|
/// MoonCheck command line interface.
///
/// This executable is deliberately thin: argument parsing, validation and
/// report rendering all live in the library package, where they are unit
/// tested on every backend. Here we only read files, print the rendered report
/// and pick the exit status.
async fn main {
  let argv = @env.args()
  match @lib.parse_args(argv[1:]) {
    @lib.CliCommand::Help => println(@lib.usage_text())
    @lib.CliCommand::Version => println(@lib.version_text())
    @lib.CliCommand::Invalid(msg) => {
      println(@lib.usage_text())
      @abort.abort("error: \{msg}")
    }
    @lib.CliCommand::CheckSchema(opts) => check_schema(opts.path)
    @lib.CliCommand::Validate(opts) => validate_all(opts)
  }
}

///|
/// Report whether a schema document is well formed.
async fn check_schema(path : String) -> Unit {
  let text = read_or_abort(path)
  match @lib.parse_schema_text(text) {
    Ok(_) => println("schema is valid: \{path}")
    Err(reason) => @abort.abort("error: invalid schema \"\{path}\": \{reason}")
  }
}

///|
/// Validate every data document against one schema and report as a whole.
async fn validate_all(opts : @lib.ValidateOptions) -> Unit {
  let schema_text = read_or_abort(opts.schema)
  let schema = match @lib.parse_schema_text(schema_text) {
    Ok(schema) => schema
    Err(reason) =>
      @abort.abort("error: invalid schema \"\{opts.schema}\": \{reason}")
  }
  let results : Array[@lib.FileResult] = []
  for path in opts.data {
    let text = read_or_abort(path)
    results.push(@lib.FileResult::new(path, @lib.validate_text(schema, text)))
  }
  let report = @lib.RunReport::new(opts.schema, results)
  let rendered = @lib.render(report, opts.format, opts.quiet)
  if rendered != "" {
    println(rendered)
  }
  if !report.is_ok() {
    @abort.abort(
      "error: \{report.failed()} of \{report.results.length()} document(s) failed validation",
    )
  }
}

///|
/// Read a file as text, or stop with a clear message.
async fn read_or_abort(path : String) -> String {
  let data = @fs.read_file(path) catch {
    err => @abort.abort("error: cannot read \"\{path}\": \{err}")
  }
  let text = data.text() catch {
    err => @abort.abort("error: cannot decode \"\{path}\" as text: \{err}")
  }
  return text
}
