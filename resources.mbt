///|
/// A resource exposed by an MCP server.
pub(all) struct Resource {
  uri : String
  name : String
  mut title : String?
  mut description : String?
  mut mime_type : String?
} derive(Debug, Eq)

///|
/// Create a new resource with a URI and display name.
pub fn Resource::new(uri : String, name : String) -> Resource {
  { uri, name, title: None, description: None, mime_type: None }
}

///|
/// Set the optional display title of a resource.
pub fn Resource::with_title(self : Resource, title : String) -> Resource {
  self.title = Some(title)
  self
}

///|
/// Set the human-readable description of a resource.
pub fn Resource::describe(self : Resource, description : String) -> Resource {
  self.description = Some(description)
  self
}

///|
/// Set the IANA media type returned when the resource is read.
pub fn Resource::with_mime_type(
  self : Resource,
  mime_type : String,
) -> Resource {
  self.mime_type = Some(mime_type)
  self
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
  mut title : String?
  mut description : String?
  mut mime_type : String?
} derive(Debug, Eq)

///|
/// Create a parameterized resource using an RFC 6570 URI template.
pub fn ResourceTemplate::new(
  uri_template : String,
  name : String,
) -> ResourceTemplate {
  { uri_template, name, title: None, description: None, mime_type: None }
}

///|
/// Set the optional display title of a resource template.
pub fn ResourceTemplate::with_title(
  self : ResourceTemplate,
  title : String,
) -> ResourceTemplate {
  self.title = Some(title)
  self
}

///|
/// Set the human-readable description of a resource template.
pub fn ResourceTemplate::describe(
  self : ResourceTemplate,
  description : String,
) -> ResourceTemplate {
  self.description = Some(description)
  self
}

///|
/// Set the IANA media type produced by a resource template.
pub fn ResourceTemplate::with_mime_type(
  self : ResourceTemplate,
  mime_type : String,
) -> ResourceTemplate {
  self.mime_type = Some(mime_type)
  self
}

///|
/// Encode a [ResourceTemplate] to JSON.
pub fn ResourceTemplate::to_json(self : ResourceTemplate) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["uriTemplate"] = Json::string(self.uri_template)
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
/// Construct a read result from several resource-content values.
pub fn ReadResourceResult::new(
  contents : Array[ResourceContents],
) -> ReadResourceResult {
  { contents, }
}

///|
/// Encode [ReadResourceResult] to JSON.
pub fn ReadResourceResult::to_json(self : ReadResourceResult) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["contents"] = Json::array(self.contents.map(fn(c) { c.to_json() }))
  Json::object(obj)
}
