///|
/// A resource exposed by an MCP server.
pub(all) struct Resource {
  uri : String
  name : String
  title : String?
  description : String?
  mime_type : String?
} derive(Debug, Eq)

///|
/// Create a new resource with a URI and display name.
pub fn Resource::new(uri : String, name : String) -> Resource {
  { uri, name, title: None, description: None, mime_type: None }
}

///|
/// Encode a [Resource] to JSON.
pub fn Resource::to_json(self : Resource) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["uri"] = Json::string(self.uri)
  obj["name"] = Json::string(self.name)
  match self.title {
    Some(t) => obj["title"] = Json::string(t)
    None => ()
  }
  match self.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  match self.mime_type {
    Some(m) => obj["mimeType"] = Json::string(m)
    None => ()
  }
  Json::object(obj)
}

///|
/// A parameterized resource template (URI Template RFC 6570).
pub(all) struct ResourceTemplate {
  uri_template : String
  name : String
  title : String?
  description : String?
  mime_type : String?
} derive(Debug, Eq)

///|
/// Result of reading a resource.
pub(all) struct ReadResourceResult {
  contents : Array[ResourceContents]
} derive(Debug, Eq)

///|
/// Construct a read result from a single text resource.
pub fn ReadResourceResult::text(
  uri : String,
  text : String,
) -> ReadResourceResult {
  { contents: [TextResourceContents(uri, None, text)] }
}

///|
/// Encode [ReadResourceResult] to JSON.
pub fn ReadResourceResult::to_json(self : ReadResourceResult) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["contents"] = Json::array(self.contents.map(fn(c) { c.to_json() }))
  Json::object(obj)
}
