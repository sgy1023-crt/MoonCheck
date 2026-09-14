// Black-box tests: exercise MoonCheck through its public API only, the way a
// consumer (or the CLI) would use it. Schemas come from JSON documents, data
// is parsed from JSON text, and results are read back as values.

///|
fn ok_errors(errors : Array[@MoonCheck.ValidationError]) -> Bool {
  errors.is_empty()
}

///|
test "end to end: valid payload" {
  let schema_text = "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"required\":true,\"minLength\":1},\"age\":{\"type\":\"int\",\"required\":false,\"min\":0,\"max\":150}}}"
  let data_text = "{\"name\":\"alice\",\"age\":30}"
  match @MoonCheck.validate_strings(schema_text, data_text) {
    Ok(errors) => assert_true(ok_errors(errors))
    Err(reason) => fail(reason)
  }
}

///|
test "end to end: invalid payload reports all problems" {
  let schema_text = "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"required\":true,\"minLength\":5},\"age\":{\"type\":\"int\",\"required\":true,\"max\":150}}}"
  let data_text = "{\"name\":\"a\",\"age\":\"old\"}"
  match @MoonCheck.validate_strings(schema_text, data_text) {
    Ok(errors) => {
      assert_eq(errors.length(), 2)
      assert_eq(errors[0].path, "$.name")
      assert_eq(errors[0].message, "length must be at least 5, got 1")
      assert_eq(errors[1].path, "$.age")
      assert_eq(errors[1].message, "expected Int, got String")
    }
    Err(reason) => fail(reason)
  }
}

///|
test "end to end: malformed data text is an error" {
  let schema_text = "{\"type\":\"string\"}"
  match @MoonCheck.validate_strings(schema_text, "not json") {
    Err(_) => ()
    Ok(_) => fail("expected an error for malformed data")
  }
}

///|
test "end to end: malformed schema text is an error" {
  match @MoonCheck.validate_strings("{ oops", "\"x\"") {
    Err(_) => ()
    Ok(_) => fail("expected an error for malformed schema")
  }
}

///|
test "parse schema then validate a value" {
  let schema = @MoonCheck.parse_schema_string(
    "{\"type\":\"int\",\"min\":0,\"max\":100}",
  ) catch {
    _ => fail("schema should parse")
  }
  let value : Json = 42
  assert_true(@MoonCheck.is_valid(schema, value))
  let errors = @MoonCheck.validate(schema, 101)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].path, "$")
  assert_eq(errors[0].message, "value must be at most 100, got 101")
}

///|
test "schema parser rejects unknown type" {
  let caught = try {
    let _ = @MoonCheck.parse_schema_string("{\"type\":\"nope\"}")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

///|
test "batch report API is usable from another package" {
  let schema = match @MoonCheck.parse_schema_text("{\"type\":\"int\"}") {
    Ok(schema) => schema
    Err(reason) => fail(reason)
  }
  let results = [
    @MoonCheck.FileResult::new("ok.json", @MoonCheck.validate_text(schema, "1")),
    @MoonCheck.FileResult::new(
      "bad.json",
      @MoonCheck.validate_text(schema, "\"x\""),
    ),
  ]
  let report = @MoonCheck.RunReport::new("s.json", results)
  assert_eq(report.failed(), 1)
  assert_eq(report.total_errors(), 1)
  assert_eq(report.is_ok(), false)
  let json_text = @MoonCheck.render(
    report,
    @MoonCheck.ReportFormat::json(),
    false,
  )
  assert_true(json_text.contains("\"failed\": 1"))
  let text = @MoonCheck.render(report, @MoonCheck.ReportFormat::text(), true)
  assert_eq(text, "bad.json: $: expected Int, got String")
}
