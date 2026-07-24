///|
/// JSON Schema types supported by MCP tool input/output schemas.
pub(all) enum SchemaType {
  SchemaObject
  SchemaString
  SchemaNumber
  SchemaInteger
  SchemaBoolean
  SchemaArray
} derive(Debug, Eq)

///|
/// Convert a [SchemaType] to its JSON string representation.
fn SchemaType::to_string(self : SchemaType) -> String {
  match self {
    SchemaObject => "object"
    SchemaString => "string"
    SchemaNumber => "number"
    SchemaInteger => "integer"
    SchemaBoolean => "boolean"
    SchemaArray => "array"
  }
}

///|
/// A property definition inside an object schema.
pub(all) struct SchemaProperty {
  typ : SchemaType
  description : String?
} derive(Debug, Eq)

///|
/// A builder for constructing a JSON Schema (the subset used by MCP tools).
pub(all) struct JsonSchema {
  mut typ : SchemaType
  mut description : String?
  mut properties : Map[String, SchemaProperty]
  mut required : Array[String]
} derive(Debug, Eq)

///|
/// Create a new object schema (the root of every tool input/output schema).
pub fn JsonSchema::object() -> JsonSchema {
  { typ: SchemaObject, description: None, properties: Map([]), required: [] }
}

///|
/// Set a human-readable description for the schema.
pub fn JsonSchema::describe(self : JsonSchema, desc : String) -> JsonSchema {
  self.description = Some(desc)
  self
}

///|
/// Add a required string property to an object schema.
pub fn JsonSchema::string(self : JsonSchema, name : String) -> JsonSchema {
  self.properties[name] = { typ: SchemaString, description: None }
  self.required.push(name)
  self
}

///|
/// Add a required string property with a description.
pub fn JsonSchema::string_desc(
  self : JsonSchema,
  name : String,
  desc : String,
) -> JsonSchema {
  self.properties[name] = { typ: SchemaString, description: Some(desc) }
  self.required.push(name)
  self
}

///|
/// Add a required number property.
pub fn JsonSchema::number(self : JsonSchema, name : String) -> JsonSchema {
  self.properties[name] = { typ: SchemaNumber, description: None }
  self.required.push(name)
  self
}

///|
/// Add a required integer property.
pub fn JsonSchema::integer(self : JsonSchema, name : String) -> JsonSchema {
  self.properties[name] = { typ: SchemaInteger, description: None }
  self.required.push(name)
  self
}

///|
/// Add a required boolean property.
pub fn JsonSchema::boolean(self : JsonSchema, name : String) -> JsonSchema {
  self.properties[name] = { typ: SchemaBoolean, description: None }
  self.required.push(name)
  self
}

///|
/// Add an optional string property (not added to required).
pub fn JsonSchema::optional_string(
  self : JsonSchema,
  name : String,
) -> JsonSchema {
  self.properties[name] = { typ: SchemaString, description: None }
  self
}

///|
/// Encode a [JsonSchema] to a JSON value.
pub fn JsonSchema::to_json(self : JsonSchema) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["type"] = Json::string(self.typ.to_string())
  match self.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  // properties
  let props : Map[String, Json] = Map([])
  for k in self.properties.keys() {
    let p = self.properties[k]
    let p_obj : Map[String, Json] = Map([])
    p_obj["type"] = Json::string(p.typ.to_string())
    match p.description {
      Some(d) => p_obj["description"] = Json::string(d)
      None => ()
    }
    props[k] = Json::object(p_obj)
  }
  if props.length() > 0 {
    obj["properties"] = Json::object(props)
  }
  // required
  if self.required.length() > 0 {
    obj["required"] = Json::array(self.required.map(fn(s) { Json::string(s) }))
  }
  Json::object(obj)
}
