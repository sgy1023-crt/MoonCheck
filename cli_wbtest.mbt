// White-box tests for command line parsing.
//
// The CLI contract lives in the library precisely so these cases can be
// tested on every backend, without building or running a native binary.

///|
test "parse: no arguments is a usage error" {
  match parse_args([]) {
    Invalid(msg) => assert_true(msg.contains("expected a schema file"))
    _ => fail("expected Invalid")
  }
}

///|
test "parse: --help and --version" {
  assert_eq(parse_args(["--help"]), Help)
  assert_eq(parse_args(["-h"]), Help)
  assert_eq(parse_args(["--version"]), Version)
  assert_eq(parse_args(["-V"]), Version)
}

///|
test "parse: implicit validate with one data file" {
  match parse_args(["s.json", "d.json"]) {
    Validate(opts) => {
      assert_eq(opts.schema, "s.json")
      assert_eq(opts.data.length(), 1)
      assert_eq(opts.data[0], "d.json")
      assert_eq(opts.format, Text)
      assert_eq(opts.quiet, false)
    }
    _ => fail("expected Validate")
  }
}

///|
test "parse: explicit validate subcommand" {
  match parse_args(["validate", "s.json", "d.json"]) {
    Validate(opts) => assert_eq(opts.schema, "s.json")
    _ => fail("expected Validate")
  }
}

///|
test "parse: several data files keep their order" {
  match parse_args(["validate", "s.json", "a.json", "b.json", "c.json"]) {
    Validate(opts) => {
      assert_eq(opts.data.length(), 3)
      assert_eq(opts.data[0], "a.json")
      assert_eq(opts.data[1], "b.json")
      assert_eq(opts.data[2], "c.json")
    }
    _ => fail("expected Validate")
  }
}

///|
test "parse: schema alone is not enough" {
  match parse_args(["s.json"]) {
    Invalid(msg) => assert_true(msg.contains("at least one data file"))
    _ => fail("expected Invalid")
  }
}

///|
test "parse: --report json and text" {
  match parse_args(["s.json", "d.json", "--report", "json"]) {
    Validate(opts) => assert_eq(opts.format, Json)
    _ => fail("expected Validate with Json")
  }
  match parse_args(["s.json", "d.json", "--report", "text"]) {
    Validate(opts) => assert_eq(opts.format, Text)
    _ => fail("expected Validate with Text")
  }
}

///|
test "parse: --report rejects a bad value and a missing value" {
  match parse_args(["s.json", "d.json", "--report", "xml"]) {
    Invalid(msg) => assert_true(msg.contains("text or json"))
    _ => fail("expected Invalid")
  }
  match parse_args(["s.json", "d.json", "--report"]) {
    Invalid(msg) => assert_true(msg.contains("expects a value"))
    _ => fail("expected Invalid")
  }
}

///|
test "parse: --quiet and -q" {
  match parse_args(["s.json", "d.json", "--quiet"]) {
    Validate(opts) => assert_eq(opts.quiet, true)
    _ => fail("expected Validate with quiet")
  }
  match parse_args(["s.json", "d.json", "-q"]) {
    Validate(opts) => assert_eq(opts.quiet, true)
    _ => fail("expected Validate with quiet")
  }
}

///|
test "parse: options may follow the paths" {
  match
    parse_args(["s.json", "a.json", "b.json", "--quiet", "--report", "json"]) {
    Validate(opts) => {
      assert_eq(opts.quiet, true)
      assert_eq(opts.format, Json)
      assert_eq(opts.data.length(), 2)
    }
    _ => fail("expected Validate")
  }
}

///|
test "parse: unknown option is rejected" {
  match parse_args(["s.json", "d.json", "--verbose"]) {
    Invalid(msg) => assert_true(msg.contains("unknown option: --verbose"))
    _ => fail("expected Invalid")
  }
}

///|
test "parse: a lone dash is a path, not an option" {
  match parse_args(["s.json", "-"]) {
    Validate(opts) => assert_eq(opts.data[0], "-")
    _ => fail("expected Validate")
  }
}

///|
test "parse: check-schema takes exactly one schema file" {
  match parse_args(["check-schema", "s.json"]) {
    CheckSchema(opts) => assert_eq(opts.path, "s.json")
    _ => fail("expected CheckSchema")
  }
  match parse_args(["check-schema"]) {
    Invalid(msg) => assert_true(msg.contains("exactly one schema file"))
    _ => fail("expected Invalid")
  }
  match parse_args(["check-schema", "s.json", "d.json"]) {
    Invalid(_) => ()
    _ => fail("expected Invalid")
  }
}

///|
test "usage and version text are non-empty" {
  assert_true(usage_text().contains("mooncheck validate"))
  assert_true(usage_text().contains("--report"))
  assert_eq(version_text(), "mooncheck 0.1.0")
}

// --- end-to-end flow ------------------------------------------------------
//
// These mirror what `cmd/main` does, minus the file reading, so the whole CLI
// behaviour is covered by tests that run on every backend.

///|
test "cli flow: batch run over several documents" {
  let schema_text = "{\"type\":\"object\",\"properties\":{\"age\":{\"type\":\"int\",\"required\":true,\"min\":0}}}"
  let documents = [("a.json", "{\"age\": 3}"), ("b.json", "{\"age\": \"x\"}")]
  match
    parse_args([
      "validate", "schema.json", "a.json", "b.json", "--report", "json",
    ]) {
    Validate(opts) => {
      let schema = match parse_schema_text(schema_text) {
        Ok(schema) => schema
        Err(reason) => fail(reason)
      }
      let results : Array[FileResult] = []
      for entry in documents {
        let (name, text) = entry
        results.push(FileResult::new(name, validate_text(schema, text)))
      }
      let report = RunReport::new(opts.schema, results)
      assert_eq(opts.format, Json)
      assert_eq(report.failed(), 1)
      assert_eq(report.total_errors(), 1)
      let rendered = render(report, opts.format, opts.quiet)
      assert_true(rendered.contains("\"ok\": false"))
      assert_true(rendered.contains("\"failed\": 1"))
      assert_true(rendered.contains("expected Int, got String"))
    }
    _ => fail("expected Validate")
  }
}

///|
test "cli flow: a malformed document is reported instead of fatal" {
  let schema = match parse_schema_text("{\"type\":\"string\"}") {
    Ok(schema) => schema
    Err(reason) => fail(reason)
  }
  let errors = validate_text(schema, "not json")
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, InvalidJson)
  assert_eq(error_kind_name(errors[0].kind), "invalid_json")
  assert_eq(errors[0].path, "$")
}

///|
test "cli flow: a broken schema is reported separately from data" {
  match parse_schema_text("{\"type\":\"nope\"}") {
    Err(reason) => assert_true(reason.contains("unknown schema type"))
    Ok(_) => fail("a broken schema must not parse")
  }
}
