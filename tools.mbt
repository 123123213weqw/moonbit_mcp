///|
/// Behavioral hints about a tool (all are advisory, not enforced).
pub(all) struct ToolAnnotations {
  title : String?
  read_only_hint : Bool
  destructive_hint : Bool
  idempotent_hint : Bool
  open_world_hint : Bool
} derive(Debug, Eq)

///|
/// Default tool annotations.
pub fn ToolAnnotations::new() -> ToolAnnotations {
  {
    title: None,
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: true,
  }
}

///|
/// A tool definition registered on an MCP server.
pub(all) struct Tool {
  name : String
  mut title : String?
  mut description : String?
  input_schema : JsonSchema
  mut output_schema : JsonSchema?
  mut annotations : ToolAnnotations?
} derive(Debug, Eq)

///|
/// Create a new tool with the given name and input schema.
pub fn Tool::new(name : String, schema : JsonSchema) -> Tool {
  {
    name,
    title: None,
    description: None,
    input_schema: schema,
    output_schema: None,
    annotations: None,
  }
}

///|
/// Set the tool's human-readable description.
pub fn Tool::describe(self : Tool, desc : String) -> Tool {
  self.description = Some(desc)
  self
}

///|
/// Encode a [Tool] to its JSON representation (for tools/list responses).
pub fn Tool::to_json(self : Tool) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["name"] = Json::string(self.name)
  match self.title {
    Some(t) => obj["title"] = Json::string(t)
    None => ()
  }
  match self.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  obj["inputSchema"] = self.input_schema.to_json()
  match self.output_schema {
    Some(s) => obj["outputSchema"] = s.to_json()
    None => ()
  }
  match self.annotations {
    Some(ann) => {
      let ann_obj : Map[String, Json] = Map([])
      ann_obj["readOnlyHint"] = if ann.read_only_hint {
        Json::boolean(true)
      } else {
        Json::boolean(false)
      }
      ann_obj["destructiveHint"] = if ann.destructive_hint {
        Json::boolean(true)
      } else {
        Json::boolean(false)
      }
      ann_obj["idempotentHint"] = if ann.idempotent_hint {
        Json::boolean(true)
      } else {
        Json::boolean(false)
      }
      ann_obj["openWorldHint"] = if ann.open_world_hint {
        Json::boolean(true)
      } else {
        Json::boolean(false)
      }
      obj["annotations"] = Json::object(ann_obj)
    }
    None => ()
  }
  Json::object(obj)
}

///|
/// Result of calling a tool.
pub(all) struct CallToolResult {
  content : Array[ContentBlock]
  structured_content : Json?
  is_error : Bool
} derive(Debug, Eq)

///|
/// Construct a successful text result.
pub fn CallToolResult::text(text : String) -> CallToolResult {
  { content: [text_content(text)], structured_content: None, is_error: false }
}

///|
/// Construct an error result (business error — the tool ran but failed).
pub fn CallToolResult::error(text : String) -> CallToolResult {
  { content: [text_content(text)], structured_content: None, is_error: true }
}

///|
/// Encode [CallToolResult] to JSON.
pub fn CallToolResult::to_json(self : CallToolResult) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["content"] = content_blocks_to_json(self.content)
  match self.structured_content {
    Some(sc) => obj["structuredContent"] = sc
    None => ()
  }
  obj["isError"] = if self.is_error {
    Json::boolean(true)
  } else {
    Json::boolean(false)
  }
  Json::object(obj)
}

///|
/// Encode an array of tools for a tools/list response.
pub fn tools_to_json(tools : Array[Tool]) -> Json {
  Json::array(tools.map(fn(t) { t.to_json() }))
}
