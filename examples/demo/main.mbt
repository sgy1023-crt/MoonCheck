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
    #|  "properties": {
    #|    "username": { "type": "string", "required": true, "minLength": 3, "maxLength": 20 },
    #|    "age":      { "type": "int", "required": true, "min": 0, "max": 150 },
    #|    "email":    { "type": "string", "required": false }
    #|  }
    #|}
  let rest_data = #|{ "username": "alice", "age": 30, "email": "alice@example.com" }
  run(rest_schema, rest_data)

  println("\n== JSON config file ==")
  let cfg_schema =
    #|{
    #|  "type": "object",
    #|  "properties": {
    #|    "host":    { "type": "string", "required": true, "minLength": 1 },
    #|    "port":    { "type": "int", "required": true, "min": 1, "max": 65535 },
    #|    "debug":   { "type": "bool", "required": false },
    #|    "timeout": { "type": "int", "required": false, "min": 0 }
    #|  }
    #|}
  let cfg_data = #|{ "host": "localhost", "port": 0, "debug": true }
  run(cfg_schema, cfg_data)

  println("\n== AI agent tool call ==")
  let tool_schema =
    #|{
    #|  "type": "object",
    #|  "properties": {
    #|    "action": { "type": "string", "required": true, "enum": ["click", "type", "scroll"] },
    #|    "x":      { "type": "int", "required": true, "min": 0, "max": 1920 },
    #|    "y":      { "type": "int", "required": true, "min": 0, "max": 1080 }
    #|  }
    #|}
  let tool_data = #|{ "action": "click", "x": 123, "y": 456 }
  run(tool_schema, tool_data)
}

fn run(schema_text : String, data_text : String) -> Unit {
  match @lib.validate_strings(schema_text, data_text) {
    Ok(errors) if errors.is_empty() => println("  valid")
    Ok(errors) => for error in errors {
      println("  \{@lib.to_string(error)}")
    }
    Err(reason) => println("  error: \{reason}")
  }
}
