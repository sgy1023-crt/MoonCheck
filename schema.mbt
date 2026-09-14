// Schema description language for MoonCheck.
//
// A `Type` value describes what kind of JSON value is allowed and which
// constraints apply to it. It is intentionally small: a handful of kinds plus
// a few constraints, enough for common API / config / tool-call validation.
//
// Schemas are usually obtained by parsing a lightweight JSON schema file
// (see `json_schema.mbt`), but they can also be built directly in code.

///|
/// Constraint set for string values.
pub struct StrSpec {
  /// Minimum allowed length in characters.
  min_length : Int?
  /// Maximum allowed length in characters.
  max_length : Int?
}

///|
/// Constraint set shared by `Int` and `Num` (number) values.
pub struct NumSpec {
  /// Inclusive lower bound.
  min : Double?
  /// Inclusive upper bound.
  max : Double?
}

///|
/// Constraint set for arrays.
pub struct ArrSpec {
  /// Schema applied to every element.
  item : Type
  /// Minimum allowed number of elements.
  min_length : Int?
  /// Maximum allowed number of elements.
  max_length : Int?
}

///|
/// A single declared property of an object schema.
pub struct Prop {
  /// The schema the property value must satisfy.
  typ : Type
  /// Whether the property must be present in the object.
  required : Bool
  /// If set, the value must equal one of the listed JSON literals.
  enums : Array[Json]?
}

///|
/// Constraint set for objects.
pub struct ObjSpec {
  /// Declared properties, by name.
  properties : Map[String, Prop]
}

///|
/// The schema of a JSON value.
pub enum Type {
  /// A JSON string, optionally length-constrained.
  Str(StrSpec)
  /// Any JSON number (integer or decimal).
  Num(NumSpec)
  /// A JSON number that must be an integer.
  Int(NumSpec)
  /// A JSON boolean.
  Bool
  /// A JSON object with declared properties.
  Obj(ObjSpec)
  /// A JSON array of elements matching `item`.
  Arr(ArrSpec)
}

///|
/// The human-facing name of a schema kind, used in error messages.
/// For example `Int` becomes `"Int"`.
pub fn kind_name(typ : Type) -> String {
  match typ {
    Str(_) => "String"
    Num(_) => "Number"
    Int(_) => "Int"
    Bool => "Bool"
    Obj(_) => "Object"
    Arr(_) => "Array"
  }
}

///|
/// The JSON type name of a concrete value, used in error messages.
pub fn value_name(value : Json) -> String {
  match value {
    Null => "Null"
    True | False => "Bool"
    Number(_, ..) => "Number"
    String(_) => "String"
    Array(_) => "Array"
    Object(_) => "Object"
  }
}
