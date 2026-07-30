///|
test "connection answers a complete request" {
  let server = Server::new("s", "1.0")
  let out = BufferedTransport::new()
  let conn = ServerConnection::new(server, out)
  conn.receive("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}\n")
  let msgs = out.messages()
  assert_true(msgs.length() == 1)
  assert_true(msgs[0].contains("ping") || msgs[0].contains("result"))
}

///|
test "connection frames a stream split mid-message" {
  let server = Server::new("s", "1.0")
  let out = BufferedTransport::new()
  let conn = ServerConnection::new(server, out)
  conn.receive("{\"jsonrpc\":\"2.0\",\"id\":1,\"me")
  assert_true(out.messages().length() == 0)
  assert_true(conn.has_pending())
  conn.receive("thod\":\"ping\"}\n")
  assert_true(out.messages().length() == 1)
  assert_true(!conn.has_pending())
}

///|
test "connection sends nothing for a notification" {
  let server = Server::new("s", "1.0")
  let out = BufferedTransport::new()
  let conn = ServerConnection::new(server, out)
  conn.receive(
    "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n",
  )
  assert_true(out.messages().length() == 0)
}

///|
test "connection handles several messages in one chunk" {
  let server = Server::new("s", "1.0")
  let out = BufferedTransport::new()
  let conn = ServerConnection::new(server, out)
  let chunk = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"ping\"}\n"
  conn.receive(chunk)
  assert_true(out.messages().length() == 2)
}

///|
test "connection receive_line dispatches a single message" {
  let server = Server::new("s", "1.0")
  let out = BufferedTransport::new()
  let conn = ServerConnection::new(server, out)
  conn.receive_line("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"ping\"}")
  assert_true(out.messages().length() == 1)
}

///|
test "connection drives a high-level McpServer tool call" {
  let mcp = McpServer::new("echo", "1.0")
  ignore(
    mcp.tool("echo", JsonSchema::object() |> JsonSchema::string("message"), fn(
      args,
    ) {
      let msg = match args {
        Object(o) =>
          match o["message"] {
            String(s) => s
            _ => "?"
          }
        _ => "?"
      }
      CallToolResult::text(msg)
    }),
  )
  let out = BufferedTransport::new()
  let conn = ServerConnection::new(mcp.inner(), out)
  conn.receive_line(
    "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{\"message\":\"hi\"}}}",
  )
  let msgs = out.messages()
  assert_true(msgs.length() == 1)
  assert_true(msgs[0].contains("hi"))
  assert_true(msgs[0].contains("isError\":false"))
}
