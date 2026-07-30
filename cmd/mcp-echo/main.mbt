///|
/// Build the echo server: a single `echo` tool that returns its message.
fn build_server() -> @mcp.Server {
  let mcp = @mcp.McpServer::new("echo-server", "0.4.0")
  ignore(
    mcp.tool_desc(
      "echo",
      "Echo back the provided message.",
      @mcp.JsonSchema::object() |> @mcp.JsonSchema::string("message"),
      fn(args) {
        let msg = match args {
          Object(o) =>
            match o["message"] {
              String(s) => s
              _ => args.stringify()
            }
          _ => args.stringify()
        }
        @mcp.CallToolResult::text("echo: " + msg)
      },
    ),
  )
  mcp.inner()
}

///|
/// Run the echo server against a single in-memory initialize request and print
/// the response. A stdio front-end is added next.
fn main {
  let server = build_server()
  let init = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"demo\",\"version\":\"0.0.0\"}}}"
  match server.process_message(init) {
    Some(resp) => println(resp)
    None => ()
  }
}
