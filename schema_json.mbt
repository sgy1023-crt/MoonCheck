// Parse a MoonCheck schema from its JSON representation.
//
// Schemas can be written by hand as JSON documents (this is what the CLI
// reads). The format is intentionally tiny:
//
// ```json
// {
//   "type": "object",
//   "properties": {
//     "name": { "type": "string", "required": true, "minLength": 1 },
//     "age":  { "type": "int", "min": 0, "max": 150 }
//   }
// }
// ```
//
// Supported `type` values: `string`, `number`, `int`, `bool`, `object`,
// `array`.
//
// Supported keys per kind:
//   - all        : `type`
//   - string     : `minLength`, `maxLength`
//   - int/number : `min`, `max`
//   - object     : `properties` (map of property schemas)
//   - property   : `required` (bool, default false), `enum` (array of literals)
//   - array      : `items` (required), `minItems`, `maxItems`
//
// Unknown keys are ignored so schemas can carry extra documentation.

///|
/// Raised when a schema document is malformed.
pub(all) suberror SchemaError {
  /// Human-readable description of what is wrong.
  InvalidSchema(String)
} derive(Eq, @debug.Debug)

///|
/// Parse a schema `Type` from its JSON representation.
pub fn parse_schema(json : Json) -> Type raise SchemaError {
  let members = require_object(json, "a schema must be a JSON object")
  return parse_node(members)
}

///|
/// Parse a schema `Type` from a JSON document string.
pub fn parse_schema_string(input : String) -> Type raise SchemaError {
  let json = @json.parse(input) catch {
    err => raise SchemaError::InvalidSchema("invalid JSON in schema: \{err}")
  }
  return parse_schema(json)
}

///|
fn parse_node(members : Map[String, Json]) -> Type raise SchemaError {
  let kind = match members.get("type") {
    None => raise SchemaError::InvalidSchema("schema is missing a \"type\" key")
    Some(String(s)) => s
    Some(_) => raise SchemaError::InvalidSchema("\"type\" must be a string")
  }
  match kind {
    "string" =>
      Str({
        min_length: get_length(members, "minLength"),
        max_length: get_length(members, "maxLength"),
      })
    "number" =>
      Num({ min: get_number(members, "min"), max: get_number(members, "max"), })
    "int" =>
      Int({ min: get_number(members, "min"), max: get_number(members, "max"), })
    "bool" => Bool
    "object" => parse_object(members)
    "array" => parse_array(members)
    _ => raise SchemaError::InvalidSchema("unknown schema type: \"\{kind}\"")
  }
}

///|
fn parse_object(members : Map[String, Json]) -> Type raise SchemaError {
  let properties_json = match members.get("properties") {
    None =>
      raise SchemaError::InvalidSchema(
        "object schema is missing \"properties\"",
      )
    Some(v) => v
  }
  let property_map = match properties_json {
    Object(m) => m
    _ => raise SchemaError::InvalidSchema("\"properties\" must be an object")
  }
  let properties : Map[String, Prop] = Map([])
  for (name, node) in property_map {
    let node_members = match node {
      Object(m) => m
      _ =>
        raise SchemaError::InvalidSchema(
          "property \"\{name}\" must be an object schema",
        )
    }
    let typ = parse_node(node_members)
    let required = get_bool_default(node_members, "required", false)
    let enums = get_enum(node_members)
    properties.set(name, { typ, required, enums, })
  }
  return Obj({ properties, })
}

///|
fn parse_array(members : Map[String, Json]) -> Type raise SchemaError {
  let items_json = match members.get("items") {
    None =>
      raise SchemaError::InvalidSchema("array schema is missing \"items\"")
    Some(v) => v
  }
  let item_members = match items_json {
    Object(m) => m
    _ => raise SchemaError::InvalidSchema("\"items\" must be an object schema")
  }
  let item = parse_node(item_members)
  return Arr({
    item,
    min_length: get_length(members, "minItems"),
    max_length: get_length(members, "maxItems"),
  })
}

///|
fn require_object(
  json : Json,
  hint : String,
) -> Map[String, Json] raise SchemaError {
  match json {
    Object(m) => m
    _ => raise SchemaError::InvalidSchema(hint)
  }
}

///|
fn get_bool_default(
  members : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool raise SchemaError {
  match members.get(key) {
    None => default
    Some(True) => true
    Some(False) => false
    Some(_) => raise SchemaError::InvalidSchema("\"\{key}\" must be a boolean")
  }
}

///|
fn get_length(
  members : Map[String, Json],
  key : String,
) -> Int? raise SchemaError {
  match members.get(key) {
    None => None
    Some(Number(n, ..)) if n == @double.floor(n) => Some(n.to_int())
    Some(Number(_, ..)) =>
      raise SchemaError::InvalidSchema("\"\{key}\" must be a whole number")
    Some(_) => raise SchemaError::InvalidSchema("\"\{key}\" must be a number")
  }
}

///|
fn get_number(
  members : Map[String, Json],
  key : String,
) -> Double? raise SchemaError {
  match members.get(key) {
    None => None
    Some(Number(n, ..)) => Some(n)
    Some(_) => raise SchemaError::InvalidSchema("\"\{key}\" must be a number")
  }
}

///|
fn get_enum(members : Map[String, Json]) -> Array[Json]? raise SchemaError {
  match members.get("enum") {
    None => None
    Some(Array(values)) => Some(values)
    Some(_) => raise SchemaError::InvalidSchema("\"enum\" must be an array")
  }
}
