/// MoonCheck command line interface.
///
/// Usage:
///   mooncheck validate <schema.json> <data.json>
///
/// Prints a report and exits with:
///   - 0 when the data is valid
///   - non-zero when it is invalid or an error occurred
///
/// The leading `validate` subcommand is optional; passing two file paths
/// directly is equivalent.

async fn main {
  let argv = @env.args()
  let args = argv[1:]
  if args.is_empty() {
    println(usage())
    @abort.abort("error: expected a schema file and a data file")
  }
  if args[0] == "--help" || args[0] == "-h" {
    println(usage())
    return
  }
  if args[0] == "--version" || args[0] == "-V" {
    println(version())
    return
  }

  // Accept an optional leading `validate` subcommand.
  let offset = if args[0] == "validate" { 1 } else { 0 }
  if args.length() < offset + 2 {
    println(usage())
    @abort.abort("error: expected a schema file and a data file")
  }
  let schema_path = args[offset]
  let data_path = args[offset + 1]

  let schema_text = read_or_abort(schema_path)
  let data_text = read_or_abort(data_path)

  match @lib.validate_strings(schema_text, data_text) {
    Err(reason) => @abort.abort("error: \{reason}")
    Ok(errors) if errors.is_empty() =>
      println("valid: data matches the schema")
    Ok(errors) => {
      for error in errors {
        println(@lib.to_string(error))
      }
      @abort.abort("error: \{errors.length()} validation error(s)")
    }
  }
}

async fn read_or_abort(path : String) -> String {
  let data = try {
    @fs.read_file(path)
  } catch {
    err => @abort.abort("error: cannot read \"\{path}\": \{err}")
  }
  let text = try {
    data.text()
  } catch {
    err => @abort.abort("error: cannot decode \"\{path}\" as text: \{err}")
  }
  return text
}

fn usage() -> String {
  let text =
    #|MoonCheck - validate JSON data against a lightweight schema
    #|
    #|Usage:
    #|  mooncheck validate <schema.json> <data.json>
    #|
    #|Arguments:
    #|  schema.json   path to the schema document
    #|  data.json     path to the JSON data to validate
    #|
    #|Options:
    #|  -h, --help     Show this help message
    #|  -V, --version  Show version
    #|
    #|Exit codes:
    #|  0   data is valid
    #|  1   data is invalid (errors are printed)
    #|  2   usage or I/O error
  return text
}

fn version() -> String {
  return "mooncheck 0.1.0"
}
