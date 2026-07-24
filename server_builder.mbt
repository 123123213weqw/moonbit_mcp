///|
/// Tool handler callback type: receives the arguments JSON and returns a result.
pub type ToolCallback = (Json) -> CallToolResult

///|
/// High-level MCP server builder with ergonomic tool/resource/prompt registration.
pub(all) struct McpServer {
  server : Server
  mut tools : Array[Tool]
  mut tool_callbacks : Map[String, ToolCallback]
}

///|
/// Create a new high-level server builder.
pub fn McpServer::new(name : String, version : String) -> McpServer {
  let server = Server::new(name, version).with_tools()
  let s : McpServer = { server, tools: [], tool_callbacks: Map([]) }
  s.register_builtin_handlers()
  s
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
      let tool_name = match obj["name"] {
        String(s) => s
        _ => return Err(InvalidArguments("tools/call requires a 'name' string"))
      }
      let arguments = obj["arguments"]
      match callbacks.get(tool_name) {
        Some(cb) => {
          let result = cb(arguments)
          Ok(result.to_json())
        }
        None => Err(UnknownTarget("tool: " + tool_name))
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
