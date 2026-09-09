// White-box tests for the MoonCheck engine.
//
// These live inside the package scope, so they can construct schemas directly
// and inspect internal helpers. Public, end-to-end behavior is covered in
// `MoonCheck_test.mbt`.

// --- helpers ---------------------------------------------------------------

fn str_schema(min_length : Int?, max_length : Int?) -> Type {
  Str({ min_length, max_length })
}

fn int_schema(min : Double?, max : Double?) -> Type {
  Int({ min, max })
}

fn obj1(props : Map[String, Prop]) -> Type {
  Obj({ properties: props })
}

// --- string ----------------------------------------------------------------

test "valid string" {
  let schema : Type = str_schema(None, None)
  let value : Json = "hello"
  assert_true(is_valid(schema, value))
}

test "string too short" {
  let schema : Type = str_schema(Some(3), None)
  let value : Json = "ab"
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, TooShort)
  assert_eq(errors[0].message, "length must be at least 3, got 2")
  assert_eq(to_string(errors[0]), "$: length must be at least 3, got 2")
}

test "string too long" {
  let schema : Type = str_schema(None, Some(2))
  let value : Json = "abcd"
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, TooLong)
}

test "string rejects number" {
  let schema : Type = str_schema(None, None)
  let value : Json = 5
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, Type)
  assert_eq(errors[0].message, "expected String, got Number")
}

// --- numeric ---------------------------------------------------------------

test "valid int within range" {
  let schema : Type = int_schema(Some(0.0), Some(150.0))
  let value : Json = 42
  assert_true(is_valid(schema, value))
}

test "int rejects decimal" {
  let schema : Type = int_schema(None, None)
  let value : Json = 3.5
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, Type)
  assert_eq(errors[0].message, "expected Int, got Number")
}

test "int rejects string" {
  let schema : Type = int_schema(None, None)
  let value : Json = "42"
  let errors = validate(schema, value)
  assert_eq(errors[0].message, "expected Int, got String")
}

test "int below minimum" {
  let schema : Type = int_schema(Some(0.0), None)
  let value : Json = -1
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, BelowMinimum)
}

test "int above maximum" {
  let schema : Type = int_schema(None, Some(10.0))
  let value : Json = 11
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, AboveMaximum)
}

test "number accepts decimals" {
  let schema : Type = Num({ min: None, max: None })
  let value : Json = 3.25
  assert_true(is_valid(schema, value))
}

test "int boundary inclusive" {
  let schema : Type = int_schema(Some(0.0), Some(10.0))
  assert_true(is_valid(schema, 0))
  assert_true(is_valid(schema, 10))
}

// --- bool ------------------------------------------------------------------

test "valid bool" {
  let schema : Type = Bool
  assert_true(is_valid(schema, true))
  assert_true(is_valid(schema, false))
}

test "bool rejects non bool" {
  let schema : Type = Bool
  let errors = validate(schema, "yes")
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].message, "expected Bool, got String")
}

// --- object ----------------------------------------------------------------

fn user_props() -> Map[String, Prop] {
  let m = Map([])
  m.set("name", { typ: str_schema(None, None), required: true, enums: None })
  m.set("age", { typ: int_schema(Some(0.0), Some(150.0)), required: false, enums: None })
  return m
}

test "valid object" {
  let schema : Type = obj1(user_props())
  let value : Json = { "name": "alice", "age": 30 }
  assert_true(is_valid(schema, value))
}

test "object ignores undeclared fields" {
  let schema : Type = obj1(user_props())
  let value : Json = { "name": "alice", "city": "Beijing" }
  assert_true(is_valid(schema, value))
}

test "object missing required field" {
  let schema : Type = obj1(user_props())
  let value : Json = { "age": 30 }
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, MissingRequired)
  assert_eq(errors[0].path, "$.name")
  assert_eq(to_string(errors[0]), "$.name: required field is missing")
}

test "object optional field may be absent" {
  let schema : Type = obj1(user_props())
  let value : Json = { "name": "alice" }
  assert_true(is_valid(schema, value))
}

test "object field type error path" {
  let schema : Type = obj1(user_props())
  let value : Json = { "name": "alice", "age": "old" }
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].path, "$.age")
  assert_eq(errors[0].message, "expected Int, got String")
}

test "object is not an object" {
  let schema : Type = obj1(user_props())
  let value : Json = [1, 2]
  let errors = validate(schema, value)
  assert_eq(errors[0].message, "expected Object, got Array")
}

// --- nested object ---------------------------------------------------------

fn profile_schema() -> Type {
  let inner = Map([])
  inner.set("email", { typ: str_schema(None, None), required: true, enums: None })
  let outer = Map([])
  outer.set("user", { typ: obj1(inner), required: true, enums: None })
  return obj1(outer)
}

test "valid nested object" {
  let schema : Type = profile_schema()
  let value : Json = { "user": { "email": "a@b.com" } }
  assert_true(is_valid(schema, value))
}

test "nested object missing inner required" {
  let schema : Type = profile_schema()
  let value : Json = { "user": {} }
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].path, "$.user.email")
  assert_eq(errors[0].kind, MissingRequired)
}

test "nested object wrong inner type path" {
  let schema : Type = profile_schema()
  let value : Json = { "user": { "email": 42 } }
  let errors = validate(schema, value)
  assert_eq(errors[0].path, "$.user.email")
  assert_eq(errors[0].message, "expected String, got Number")
}

test "nested required object missing at top" {
  let schema : Type = profile_schema()
  let value : Json = {}
  let errors = validate(schema, value)
  assert_eq(errors[0].path, "$.user")
}

// --- array -----------------------------------------------------------------

test "valid array of ints" {
  let schema : Type = Arr({ item: int_schema(None, None), min_length: None, max_length: None })
  let value : Json = [1, 2, 3]
  assert_true(is_valid(schema, value))
}

test "array element type error path" {
  let schema : Type = Arr({ item: int_schema(None, None), min_length: None, max_length: None })
  let value : Json = [1, "two", 3]
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].path, "$[1]")
  assert_eq(errors[0].message, "expected Int, got String")
}

test "array length bounds" {
  let schema : Type = Arr({ item: int_schema(None, None), min_length: Some(2), max_length: Some(3) })
  let errors_short = validate(schema, [1])
  assert_eq(errors_short.length(), 1)
  assert_eq(errors_short[0].kind, TooShort)
  let errors_long = validate(schema, [1, 2, 3, 4])
  assert_eq(errors_long.length(), 1)
  assert_eq(errors_long[0].kind, TooLong)
}

test "array element nested error" {
  let schema : Type = Arr({
    item: obj1(user_props()),
    min_length: None,
    max_length: None,
  })
  let value : Json = [{ "name": "a" }, {}]
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].path, "$[1].name")
}

test "array is not an array" {
  let schema : Type = Arr({ item: int_schema(None, None), min_length: None, max_length: None })
  let errors = validate(schema, 5)
  assert_eq(errors[0].message, "expected Array, got Number")
}

// --- enum ------------------------------------------------------------------

test "valid enum value" {
  let m = Map([])
  m.set(
    "method",
    { typ: str_schema(None, None), required: true, enums: Some([("GET" : Json), ("POST" : Json)]) },
  )
  let schema : Type = obj1(m)
  let value : Json = { "method": "POST" }
  assert_true(is_valid(schema, value))
}

test "enum rejects unknown value" {
  let m = Map([])
  m.set(
    "method",
    { typ: str_schema(None, None), required: true, enums: Some([("GET" : Json), ("POST" : Json)]) },
  )
  let schema : Type = obj1(m)
  let value : Json = { "method": "DELETE" }
  let errors = validate(schema, value)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].kind, NotInEnum)
  assert_eq(errors[0].path, "$.method")
  assert_eq(errors[0].message, "value must be one of [\"GET\",\"POST\"]")
}

test "enum still enforces base type" {
  let m = Map([])
  m.set("method", { typ: str_schema(None, None), required: true, enums: Some([("GET" : Json)]) })
  let schema : Type = obj1(m)
  let errors = validate(schema, { "method": 3 })
  assert_eq(errors[0].kind, Type)
}
