///|
/// Runnable demo of the MoonCheck library.
///
/// Run from the project root with:
///   moon run examples/demo
///
/// It validates three example payloads end to end and prints a report for
/// each: a REST-ish payload, a JSON config file, and an AI tool call.
fn main {
  println("== REST API request payload ==")
  let rest_schema =
    #|{
    #|  "type": "object",
    #|  "required": ["username", "age"],
    #|  "properties": {
    #|    "username": { "type": "string", "minLength": 3, "maxLength": 20 },
    #|    "age":      { "type": "integer", "minimum": 0, "maximum": 150 },
    #|    "email":    { "type": "string" }
    #|  }
    #|}
  let rest_data =
    #|{ "username": "alice", "age": 30, "email": "alice@example.com" }
  run(rest_schema, rest_data)

  println("\n== JSON config file ==")
  let cfg_schema =
    #|{
    #|  "type": "object",
    #|  "required": ["host", "port"],
    #|  "properties": {
    #|    "host":    { "type": "string", "minLength": 1 },
    #|    "port":    { "type": "integer", "minimum": 1, "maximum": 65535 },
    #|    "debug":   { "type": "boolean" },
    #|    "timeout": { "type": "integer", "minimum": 0 }
    #|  }
    #|}
  let cfg_data =
    #|{ "host": "localhost", "port": 0, "debug": true }
  run(cfg_schema, cfg_data)

  println("\n== AI agent tool call ==")
  let tool_schema =
    #|{
    #|  "type": "object",
    #|  "required": ["action", "x", "y"],
    #|  "properties": {
    #|    "action": { "type": "string", "enum": ["click", "type", "scroll"] },
    #|    "x":      { "type": "integer", "minimum": 0, "maximum": 1920 },
    #|    "y":      { "type": "integer", "minimum": 0, "maximum": 1080 }
    #|  }
    #|}
  let tool_data =
    #|{ "action": "click", "x": 123, "y": 456 }
  run(tool_schema, tool_data)

  println("\n== A schema with typos is refused, not silently accepted ==")
  let typo_schema =
    #|{ "type": "object", "properties": { "port": { "type": "int", "min": 1 } } }
  let typo_data =
    #|{ "port": "not a number" }
  run(typo_schema, typo_data)
}

///|
fn run(schema_text : String, data_text : String) -> Unit {
  match @lib.validate_strings(schema_text, data_text) {
    Ok(errors) if errors.is_empty() => println("  valid")
    Ok(errors) =>
      for error in errors {
        println("  \{@lib.to_string(error)}")
      }
    Err(reason) => println("  error: \{reason}")
  }
}
