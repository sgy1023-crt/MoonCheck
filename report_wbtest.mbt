// White-box tests for report rendering (text and JSON).

///|
fn sample_error(
  path : String,
  kind : ErrorKind,
  message : String,
) -> ValidationError {
  { path, kind, message, }
}

///|
test "report: counts and ok flag" {
  let ok = FileResult::new("a.json", [])
  let bad = FileResult::new("b.json", [
    sample_error("$.age", Type, "expected Int, got String"),
  ])
  let report = RunReport::new("s.json", [ok, bad])
  assert_eq(report.failed(), 1)
  assert_eq(report.total_errors(), 1)
  assert_eq(report.is_ok(), false)
  let clean = RunReport::new("s.json", [FileResult::new("a.json", [])])
  assert_eq(clean.is_ok(), true)
  assert_eq(clean.failed(), 0)
}

///|
test "report text: single valid document prints nothing" {
  let report = RunReport::new("s.json", [FileResult::new("a.json", [])])
  assert_eq(render_text(report, false), "")
  assert_eq(render(report, Text, false), "")
}

///|
test "report text: single invalid document prints bare error lines" {
  let report = RunReport::new("s.json", [
    FileResult::new("a.json", [
      sample_error("$.name", MissingRequired, "required field is missing"),
      sample_error("$.age", Type, "expected Int, got String"),
    ]),
  ])
  assert_eq(
    render_text(report, false),
    "$.name: required field is missing\n$.age: expected Int, got String",
  )
}

///|
test "report text: several documents are prefixed and summarised" {
  let report = RunReport::new("s.json", [
    FileResult::new("a.json", []),
    FileResult::new("b.json", [
      sample_error("$.age", Type, "expected Int, got String"),
    ]),
  ])
  assert_eq(
    render_text(report, false),
    "ok: a.json\nb.json: $.age: expected Int, got String\nchecked 2 document(s): 1 ok, 1 failed, 1 error(s)",
  )
}

///|
test "report text: quiet hides successes and the summary" {
  let report = RunReport::new("s.json", [
    FileResult::new("a.json", []),
    FileResult::new("b.json", [
      sample_error("$.age", TooLong, "length must be at most 3, got 4"),
    ]),
  ])
  assert_eq(
    render_text(report, true),
    "b.json: $.age: length must be at most 3, got 4",
  )
}

///|
test "report json: is valid JSON with the documented shape" {
  let report = RunReport::new("s.json", [
    FileResult::new("a.json", []),
    FileResult::new("b.json", [
      sample_error("$.age", Type, "expected Int, got String"),
    ]),
  ])
  let text = render_json(report)
  let parsed = @json.parse(text) catch {
    _ => fail("the JSON report must be parseable JSON")
  }
  match parsed {
    Object(root) => {
      match root.get("schema") {
        Some(String(s)) => assert_eq(s, "s.json")
        _ => fail("schema should be a string")
      }
      match root.get("ok") {
        Some(False) => ()
        _ => fail("ok should be false")
      }
      match root.get("documents") {
        Some(Array(documents)) => {
          assert_eq(documents.length(), 2)
          match documents[1] {
            Object(doc) => {
              match doc.get("path") {
                Some(String(p)) => assert_eq(p, "b.json")
                _ => fail("document should have a path")
              }
              match doc.get("ok") {
                Some(False) => ()
                _ => fail("failed document should have ok=false")
              }
            }
            _ => fail("document should be an object")
          }
        }
        _ => fail("documents should be an array")
      }
      match root.get("summary") {
        Some(Object(summary)) => {
          match summary.get("checked") {
            Some(Number(n, ..)) => assert_eq(n, 2.0)
            _ => fail("summary.checked should be a number")
          }
          match summary.get("failed") {
            Some(Number(n, ..)) => assert_eq(n, 1.0)
            _ => fail("summary.failed should be a number")
          }
        }
        _ => fail("summary should be an object")
      }
    }
    _ => fail("the report root should be an object")
  }
  // The error kind is reported using its stable machine-readable name.
  assert_true(text.contains("\"kind\": \"type_mismatch\""))
  assert_true(text.contains("\"path\": \"$.age\""))
}

///|
test "report json: a clean run reports ok with no documents" {
  let report = RunReport::new("s.json", [])
  let text = render_json(report)
  assert_true(text.contains("\"ok\": true"))
  assert_true(text.contains("\"checked\": 0"))
}

///|
test "report json ignores quiet" {
  let report = RunReport::new("s.json", [FileResult::new("a.json", [])])
  assert_eq(render(report, Json, true), render(report, Json, false))
}
