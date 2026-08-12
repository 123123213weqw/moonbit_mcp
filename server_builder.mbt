///|
/// Tool handler callback type: receives the arguments JSON and returns a result.
pub type ToolCallback = (Json) -> CallToolResult

///|
/// Resource reader callback: receives the requested URI and returns its contents.
pub type ResourceCallback = (String) -> ReadResourceResult

///|
/// Prompt renderer callback: receives the supplied arguments object.
pub type PromptCallback = (Json) -> GetPromptResult

///|
/// High-level MCP server builder with ergonomic tool/resource/prompt registration.
pub(all) struct McpServer {
  server : Server
  mut tools : Array[Tool]
  mut tool_callbacks : Map[String, ToolCallback]
  mut resources : Array[Resource]
  mut resource_callbacks : Map[String, ResourceCallback]
  mut prompts : Array[Prompt]
  mut prompt_callbacks : Map[String, PromptCallback]
}

///|
/// Create a new high-level server builder.
pub fn McpServer::new(name : String, version : String) -> McpServer {
  let server = Server::new(name, version)
    .with_tools()
    .with_resources()
    .with_prompts()
  let s : McpServer = {
    server,
    tools: [],
    tool_callbacks: Map([]),
    resources: [],
    resource_callbacks: Map([]),
    prompts: [],
    prompt_callbacks: Map([]),
  }
  s.register_builtin_handlers()
  s
}

///|
/// Register a concrete resource and its reader callback.
pub fn McpServer::resource(
  self : McpServer,
  resource : Resource,
  cb : ResourceCallback,
) -> McpServer {
  self.resources.push(resource)
  self.resource_callbacks[resource.uri] = cb
  self
}

///|
/// Register a reusable prompt and its rendering callback.
pub fn McpServer::prompt(
  self : McpServer,
  prompt : Prompt,
  cb : PromptCallback,
) -> McpServer {
  self.prompts.push(prompt)
  self.prompt_callbacks[prompt.name] = cb
  self
}

///|
/// Register a tool with its input schema and callback.
pub fn McpServer::tool(
  self : McpServer,
  name : String,
  schema : JsonSchema,
  cb : ToolCallback,
) -> McpServer {
  let t = Tool::new(name, schema)
  self.tools.push(t)
  self.tool_callbacks[name] = cb
  self
}

///|
/// Register a tool with description.
pub fn McpServer::tool_desc(
  self : McpServer,
  name : String,
  desc : String,
  schema : JsonSchema,
  cb : ToolCallback,
) -> McpServer {
  let t = Tool::new(name, schema)
  t.description = Some(desc)
  self.tools.push(t)
  self.tool_callbacks[name] = cb
  self
}

///|
/// Register the built-in tools/list and tools/call handlers on the inner server.
fn McpServer::register_builtin_handlers(self : McpServer) -> Unit {
  // tools/list handler
  let tools_ref = self.tools
  ignore(
    self.server.handle_method(method_tools_list, fn(
      _params : Json,
      _ctx : ServerContext,
    ) -> Result[Json, McpError] {
      let result_obj : Map[String, Json] = Map([])
      result_obj["tools"] = tools_to_json(tools_ref)
      Ok(Json::object(result_obj))
    }),
  )
  // tools/call handler
  let callbacks = self.tool_callbacks
  ignore(
    self.server.handle_method(method_tools_call, fn(
      params : Json,
      _ctx : ServerContext,
    ) -> Result[Json, McpError] {
      // params: { "name": "...", "arguments": {...} }
      let obj = match params {
        Object(o) => o
        _ => return Err(InvalidArguments("tools/call params must be an object"))
      }
      let tool_name = match obj.get("name") {
        Some(String(s)) => s
        _ => return Err(InvalidArguments("tools/call requires a 'name' string"))
      }
      let arguments = match obj.get("arguments") {
        Some(Object(args)) => Json::object(args)
        None => Json::empty_object()
        Some(_) =>
          return Err(InvalidArguments("tools/call arguments must be an object"))
      }
      match callbacks.get(tool_name) {
        Some(cb) => {
          let result = cb(arguments)
          Ok(result.to_json())
        }
        None => Err(UnknownTarget("tool: " + tool_name))
      }
    }),
  )
  // resources/list handler
  let resources_ref = self.resources
  ignore(
    self.server.handle_method(method_resources_list, fn(
      _params : Json,
      _ctx : ServerContext,
    ) -> Result[Json, McpError] {
      let result_obj : Map[String, Json] = Map([])
      result_obj["resources"] = Json::array(
        resources_ref.map(fn(r) { r.to_json() }),
      )
      Ok(Json::object(result_obj))
    }),
  )
  // resources/read handler
  let resource_callbacks = self.resource_callbacks
  ignore(
    self.server.handle_method(method_resources_read, fn(
      params : Json,
      _ctx : ServerContext,
    ) -> Result[Json, McpError] {
      let obj = match params {
        Object(o) => o
        _ =>
          return Err(
            InvalidArguments("resources/read params must be an object"),
          )
      }
      let uri = match obj.get("uri") {
        Some(String(s)) => s
        _ =>
          return Err(InvalidArguments("resources/read requires a 'uri' string"))
      }
      match resource_callbacks.get(uri) {
        Some(cb) => Ok(cb(uri).to_json())
        None => Err(UnknownTarget("resource: " + uri))
      }
    }),
  )
  // prompts/list handler
  let prompts_ref = self.prompts
  ignore(
    self.server.handle_method(method_prompts_list, fn(
      _params : Json,
      _ctx : ServerContext,
    ) -> Result[Json, McpError] {
      let result_obj : Map[String, Json] = Map([])
      result_obj["prompts"] = Json::array(
        prompts_ref.map(fn(p) { p.to_json() }),
      )
      Ok(Json::object(result_obj))
    }),
  )
  // prompts/get handler
  let prompt_callbacks = self.prompt_callbacks
  ignore(
    self.server.handle_method(method_prompts_get, fn(
      params : Json,
      _ctx : ServerContext,
    ) -> Result[Json, McpError] {
      let obj = match params {
        Object(o) => o
        _ =>
          return Err(InvalidArguments("prompts/get params must be an object"))
      }
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ =>
          return Err(InvalidArguments("prompts/get requires a 'name' string"))
      }
      let arguments = match obj.get("arguments") {
        Some(a) => a
        None => Json::empty_object()
      }
      match prompt_callbacks.get(name) {
        Some(cb) => Ok(cb(arguments).to_json())
        None => Err(UnknownTarget("prompt: " + name))
      }
    }),
  )
}

///|
/// Process an incoming message (delegate to the inner server).
pub fn McpServer::process_message(self : McpServer, raw : String) -> String? {
  self.server.process_message(raw)
}

///|
/// Access the underlying low-level server.
pub fn McpServer::inner(self : McpServer) -> Server {
  self.server
}
