///|
/// Build the server side: an echo tool driven by a [ServerConnection].
fn build_server() -> @mcp.Server {
  let mcp = @mcp.McpServer::new("echo-server", "1.0.0")
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
/// A full MCP session in one process: a [ClientConnection] and a
/// [ServerConnection] wired back-to-back through linked in-memory transports.
/// Runs the initialize handshake, lists tools, calls the echo tool, and prints
/// every step — no stdio or network involved.
fn main {
  let server = build_server()

  // Loopback wiring: what the client sends is dispatched to the server
  // connection, and server responses are fed back to the client connection.
  let (to_server, to_client) = @mcp.InMemoryTransport::pair()
  let server_conn = @mcp.ServerConnection::new(server, to_client)
  let client = @mcp.Client::new("loopback-client", "1.0.0")
  let client_conn = @mcp.ClientConnection::new(client, to_server)
  to_client.on_message(fn(m) { server_conn.receive_line(m) })
  to_server.on_message(fn(m) { ignore(client_conn.receive_line(m)) })

  // 1. Initialize handshake.
  let init_id = client_conn.send_initialize()
  let info = match client_conn.take_initialize(init_id) {
    Ok(i) => i
    Err(e) => {
      println("initialize failed: " + e.to_message())
      return
    }
  }
  println("1. initialized with server: " + info.name + " v" + info.version)
  let version_str = match client.protocol_version() {
    Some(v) => v
    None => "?"
  }
  println("   protocol version: " + version_str)
  client_conn.send_initialized()

  // 2. List the server's tools.
  let list_id = client_conn.send_tools_list()
  let tools = match client.take_result(list_id) {
    Ok(t) => t
    Err(e) => {
      println("tools/list failed: " + e.to_message())
      return
    }
  }
  println("2. tools/list: " + tools.stringify())

  // 3. Call the echo tool.
  let args : Map[String, Json] = Map([])
  args["message"] = Json::string("hello loopback")
  let call_id = client_conn.send_tools_call("echo", Json::object(args))
  let result = match client.take_result(call_id) {
    Ok(r) => r
    Err(e) => {
      println("tools/call failed: " + e.to_message())
      return
    }
  }
  println("3. tools/call echo -> " + result.stringify())
}
