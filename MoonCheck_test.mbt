// Black-box tests: exercise MoonCheck through its public API only, the way a
// consumer (or the CLI) would use it. Schemas are standard JSON Schema
// documents validated by `mizchi/jsonschema`; data is parsed from JSON text.

///|
test "end to end: valid payload" {
  let schema_text = "{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":1},\"age\":{\"type\":\"integer\",\"minimum\":0,\"maximum\":150}}}"
  let data_text = "{\"name\":\"alice\",\"age\":30}"
  match @MoonCheck.validate_strings(schema_text, data_text) {
    Ok(errors) => assert_true(errors.is_empty())
    Err(reason) => fail(reason)
  }
}

///|
test "end to end: invalid payload reports all problems" {
  let schema_text = "{\"type\":\"object\",\"required\":[\"name\",\"age\"],\"properties\":{\"name\":{\"type\":\"string\",\"minLength\":5},\"age\":{\"type\":\"integer\",\"maximum\":150}}}"
  let data_text = "{\"name\":\"a\",\"age\":\"old\"}"
  match @MoonCheck.validate_strings(schema_text, data_text) {
    Ok(errors) => {
      assert_eq(errors.length(), 2)
      let by_path = errors.map(e => (e.path, @MoonCheck.error_kind_name(e.kind)))
      assert_true(by_path.contains(("$.name", "too_short")))
      assert_true(by_path.contains(("$.age", "type_mismatch")))
    }
    Err(reason) => fail(reason)
  }
}

///|
test "end to end: malformed data text is an error" {
  match @MoonCheck.validate_strings("{\"type\":\"string\"}", "not json") {
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
    "{\"type\":\"integer\",\"minimum\":0,\"maximum\":100}",
  ) catch {
    _ => fail("schema should parse")
  }
  assert_true(@MoonCheck.is_valid(schema, 42))
  let errors = @MoonCheck.validate(schema, 101)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].path, "$")
  assert_eq(@MoonCheck.error_kind_name(errors[0].kind), "above_max")
}

///|
test "linter rejects a schema the validator would treat as 'anything'" {
  // `mizchi/jsonschema` alone would compile `"type": "int"` to an accept-all
  // schema; MoonCheck refuses it.
  let caught = try {
    let _ = @MoonCheck.parse_schema_string("{\"type\":\"int\"}")
    false
  } catch {
    _ => true
  }
  assert_true(caught)
}

///|
test "batch report API is usable from another package" {
  let schema = match @MoonCheck.parse_schema_text("{\"type\":\"integer\"}") {
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
  assert_eq(text, "bad.json: $: Value is not a number")
}
