///|
/// A canned initialize response answering request id 1.
fn init_response_line() -> String {
  "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"serverInfo\":{\"name\":\"s\",\"version\":\"1.0\"}}}"
}

///|
test "client connection sends initialize through the transport" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  let id = conn.send_initialize()
  assert_eq(id, IdInt(1))
  let msgs = out.messages()
  assert_true(msgs.length() == 1)
  assert_true(msgs[0].contains("\"method\":\"initialize\""))
}

///|
test "client connection receive correlates a response by id" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  let id = conn.send_ping()
  assert_eq(id, IdInt(1))
  conn.receive("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}\n")
  match client.take_result(id) {
    Ok(_) => ()
    Err(_) => fail("expected a correlated result")
  }
}

///|
test "client connection frames a stream split mid-message" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  let id = conn.send_ping()
  let resp = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}"
  let half = resp.length() / 2
  conn.receive(resp[0:half].to_owned())
  assert_true(conn.has_pending())
  match client.take_result(id) {
    Ok(_) => fail("response should not be complete yet")
    Err(_) => ()
  }
  conn.receive(resp[half:].to_owned() + "\n")
  assert_true(!conn.has_pending())
  match client.take_result(id) {
    Ok(_) => ()
    Err(_) => fail("expected a correlated result after framing")
  }
}

///|
test "client connection captures server notifications" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  conn.receive(
    "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/message\",\"params\":{}}\n",
  )
  assert_true(client.received_notifications().length() == 1)
}

///|
test "client connection skips malformed lines when framing" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  conn.receive("this is not json\n")
  assert_true(client.received_notifications().length() == 0)
  // A well-formed message afterwards still gets through.
  conn.receive(
    "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/message\",\"params\":{}}\n",
  )
  assert_true(client.received_notifications().length() == 1)
}

///|
test "client connection receive_line propagates parse errors" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  match conn.receive_line("not json") {
    Ok(_) => fail("expected a parse error")
    Err(_) => ()
  }
}

///|
test "client connection take_initialize completes the handshake" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  let id = conn.send_initialize()
  conn.receive(init_response_line() + "\n")
  match conn.take_initialize(id) {
    Ok(server) => assert_eq(server.name, "s")
    Err(_) => fail("take_initialize failed")
  }
  assert_true(client.is_initialized())
  assert_eq(client.protocol_version(), Some("2025-06-18"))
}

///|
test "client connection sends the initialized notification" {
  let client = Client::new("c", "1.0")
  let out = BufferedTransport::new()
  let conn = ClientConnection::new(client, out)
  conn.send_initialized()
  let msgs = out.messages()
  assert_true(msgs.length() == 1)
  assert_true(msgs[0].contains("notifications/initialized"))
  assert_true(!msgs[0].contains("\"id\""))
}

///|
test "client connection loopback against a server connection" {
  // Server side: an echo tool driven by a ServerConnection.
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

  // Loopback wiring: messages sent on one end are handled on the other.
  let (to_server, to_client) = InMemoryTransport::pair()
  let server_conn = ServerConnection::new(mcp.inner(), to_client)
  let client = Client::new("c", "1.0")
  let client_conn = ClientConnection::new(client, to_server)
  to_client.on_message(fn(m) { server_conn.receive_line(m) })
  to_server.on_message(fn(m) { ignore(client_conn.receive_line(m)) })

  // 1. initialize handshake.
  let init_id = client_conn.send_initialize()
  match client_conn.take_initialize(init_id) {
    Ok(server) => assert_eq(server.name, "echo")
    Err(_) => fail("loopback initialize failed")
  }
  assert_true(client.is_initialized())
  client_conn.send_initialized()

  // 2. tools/list.
  let list_id = client_conn.send_tools_list()
  let tools = match client.take_result(list_id) {
    Ok(t) => t
    Err(_) => fail("loopback tools/list failed")
  }
  assert_true(tools.stringify().contains("echo"))

  // 3. tools/call echo.
  let args : Map[String, Json] = Map([])
  args["message"] = Json::string("hi")
  let call_id = client_conn.send_tools_call("echo", Json::object(args))
  let result = match client.take_result(call_id) {
    Ok(r) => r
    Err(_) => fail("loopback tools/call failed")
  }
  assert_true(result.stringify().contains("hi"))
}
