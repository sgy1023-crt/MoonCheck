// Reports: what a caller gets back after validating documents.
//
// Two renderings are supported:
//   - text: one line per error, easy to read in a terminal or a CI log
//   - JSON: a machine-readable document for CI, dashboards and scripts
//
// Both renderings are pure functions over a `RunReport`, so they are unit
// tested without any I/O.

///|
/// Output format of a validation report.
pub enum ReportFormat {
  /// One line per error (default).
  Text
  /// A JSON document, for tools.
  Json
} derive(Eq, @debug.Debug)

///|
/// The text report format.
///
/// A constructor function, so callers in other packages do not have to spell
/// out the variant.
pub fn ReportFormat::text() -> ReportFormat {
  Text
}

///|
/// The JSON report format.
pub fn ReportFormat::json() -> ReportFormat {
  Json
}

///|
/// The validation outcome for one data document.
pub struct FileResult {
  /// Name of the document, usually the path that was read.
  name : String
  /// Errors found; empty means the document is valid.
  errors : Array[ValidationError]
} derive(Eq, @debug.Debug)

///|
/// Create a `FileResult`.
pub fn FileResult::new(
  name : String,
  errors : Array[ValidationError],
) -> FileResult {
  { name, errors, }
}

///|
/// The result of validating one schema against one or more data documents.
pub struct RunReport {
  /// Name of the schema document.
  schema : String
  /// Per-document results, in input order.
  results : Array[FileResult]
} derive(Eq, @debug.Debug)

///|
/// Create a `RunReport`.
pub fn RunReport::new(
  schema : String,
  results : Array[FileResult],
) -> RunReport {
  { schema, results, }
}

///|
/// Number of documents that failed validation.
pub fn RunReport::failed(report : RunReport) -> Int {
  let mut count = 0
  for result in report.results {
    if !result.errors.is_empty() {
      count = count + 1
    }
  }
  return count
}

///|
/// Total number of errors across all documents.
pub fn RunReport::total_errors(report : RunReport) -> Int {
  let mut count = 0
  for result in report.results {
    count = count + result.errors.length()
  }
  return count
}

///|
/// `true` when every document is valid.
pub fn RunReport::is_ok(report : RunReport) -> Bool {
  report.total_errors() == 0
}

///|
/// Render the report as text.
///
/// With a single data document the output is just the error lines, which is
/// the friendly case for one-off checks. With several documents each line is
/// prefixed by the document name and a summary line is appended, which is the
/// useful case for CI.
pub fn render_text(report : RunReport, quiet : Bool) -> String {
  let lines : Array[String] = []
  let multiple = report.results.length() > 1
  for result in report.results {
    if result.errors.is_empty() {
      if !quiet && multiple {
        lines.push("ok: \{result.name}")
      }
    } else {
      for error in result.errors {
        if multiple {
          lines.push("\{result.name}: \{to_string(error)}")
        } else {
          lines.push(to_string(error))
        }
      }
    }
  }
  if multiple && !quiet {
    let ok = report.results.length() - report.failed()
    lines.push(
      "checked \{report.results.length()} document(s): \{ok} ok, \{report.failed()} failed, \{report.total_errors()} error(s)",
    )
  }
  return join_lines(lines)
}

///|
/// Render the report as a JSON document.
///
/// Shape:
/// ```json
/// {
///   "schema": "schema.json",
///   "ok": false,
///   "summary": { "checked": 2, "failed": 1, "errors": 2 },
///   "documents": [
///     { "path": "a.json", "ok": true, "errors": [] },
///     { "path": "b.json", "ok": false,
///       "errors": [ { "path": "$.age", "kind": "type_mismatch", "message": "..." } ] }
///   ]
/// }
/// ```
pub fn render_json(report : RunReport) -> String {
  let documents : Array[Json] = []
  for result in report.results {
    let errors : Array[Json] = []
    for error in result.errors {
      let entry : Map[String, Json] = Map([])
      entry.set("path", Json::string(error.path))
      entry.set("kind", Json::string(error_kind_name(error.kind)))
      entry.set("message", Json::string(error.message))
      errors.push(Json::object(entry))
    }
    let document : Map[String, Json] = Map([])
    document.set("path", Json::string(result.name))
    document.set("ok", Json::boolean(result.errors.is_empty()))
    document.set("errors", Json::array(errors))
    documents.push(Json::object(document))
  }
  let summary : Map[String, Json] = Map([])
  summary.set("checked", Json::number(report.results.length().to_double()))
  summary.set("failed", Json::number(report.failed().to_double()))
  summary.set("errors", Json::number(report.total_errors().to_double()))
  let root : Map[String, Json] = Map([])
  root.set("schema", Json::string(report.schema))
  root.set("ok", Json::boolean(report.is_ok()))
  root.set("summary", Json::object(summary))
  root.set("documents", Json::array(documents))
  return Json::object(root).stringify(indent=2)
}

///|
/// Render the report in the requested format.
///
/// `quiet` only affects the text format; the JSON format is already
/// machine-oriented and always contains everything.
pub fn render(
  report : RunReport,
  format : ReportFormat,
  quiet : Bool,
) -> String {
  match format {
    Json => render_json(report)
    Text => render_text(report, quiet)
  }
}

///|
fn join_lines(lines : Array[String]) -> String {
  let mut out = ""
  for line in lines {
    out = if out == "" { line } else { "\{out}\n\{line}" }
  }
  return out
}
