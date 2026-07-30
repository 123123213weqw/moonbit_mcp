///|
test "client allocates monotonically increasing request ids" {
  let client = Client::new("c", "1.0.0")
  let (id1, _) = client.build_ping()
  let (id2, _) = client.build_ping()
  let a = match id1 {
    IdInt(n) => n
    _ => -1
  }
  let b = match id2 {
    IdInt(n) => n
    _ => -1
  }
  assert_true(a == 1)
  assert_true(b == 2)
}

///|
test "client build_initialize advertises client info and protocol version" {
  let client = Client::new("my-client", "9.9.9")
  let (_, req) = client.build_initialize()
  assert_true(req.contains("initialize"))
  assert_true(req.contains("my-client"))
  assert_true(req.contains("9.9.9"))
  assert_true(req.contains("2025-06-18"))
}

///|
test "client build_tools_call embeds name and arguments" {
  let client = Client::new("c", "1.0.0")
  let args : Map[String, Json] = Map([])
  args["message"] = Json::string("hello")
  let (_, req) = client.build_tools_call("echo", Json::object(args))
  assert_true(req.contains("tools/call"))
  assert_true(req.contains("echo"))
  assert_true(req.contains("hello"))
}

///|
test "client initialize handshake against a server" {
  let client = Client::new("test-client", "1.0.0")
  let server = Server::new("handshake-server", "2.0.0")
  let (_, init_req) = client.build_initialize()
  match server.process_message(init_req) {
    Some(resp) =>
      match client.complete_initialize(resp) {
        Ok(info) => {
          assert_true(info.name == "handshake-server")
          assert_true(info.version == "2.0.0")
        }
        Err(_) => fail("expected initialize to succeed")
      }
    None => fail("expected an initialize response")
  }
  assert_true(client.is_initialized())
  match client.protocol_version() {
    Some(v) => assert_true(v == "2025-06-18")
    None => fail("expected a negotiated protocol version")
  }
  match client.server() {
    Some(info) => assert_true(info.name == "handshake-server")
    None => fail("expected server info to be recorded")
  }
}

///|
test "client lists and calls tools end to end" {
  let client = Client::new("test-client", "1.0.0")
  let server = McpServer::new("echo-server", "1.0.0")
  ignore(
    server.tool("echo", JsonSchema::object() |> JsonSchema::string("message"), fn(
      args,
    ) {
      let msg = match args {
        Object(o) =>
          match o["message"] {
            String(s) => s
            _ => "no message"
          }
        _ => "no args"
      }
      CallToolResult::text(msg)
    }),
  )
  // tools/list
  let (list_id, list_req) = client.build_tools_list()
  match server.process_message(list_req) {
    Some(resp) => ignore(client.handle_message(resp))
    None => fail("expected a tools/list response")
  }
  match client.take_result(list_id) {
    Ok(result) => assert_true(result.stringify().contains("echo"))
    Err(_) => fail("expected a tools/list result")
  }
  // tools/call
  let args : Map[String, Json] = Map([])
  args["message"] = Json::string("hi")
  let (call_id, call_req) = client.build_tools_call("echo", Json::object(args))
  match server.process_message(call_req) {
    Some(resp) => ignore(client.handle_message(resp))
    None => fail("expected a tools/call response")
  }
  match client.take_result(call_id) {
    Ok(result) => {
      let s = result.stringify()
      assert_true(s.contains("hi"))
      assert_true(s.contains("isError\":false"))
    }
    Err(_) => fail("expected a tools/call result")
  }
}

///|
test "client surfaces server error responses via take_result" {
  let client = Client::new("test-client", "1.0.0")
  let server = McpServer::new("echo-server", "1.0.0")
  let (err_id, err_req) = client.build_tools_call(
    "missing",
    Json::empty_object(),
  )
  match server.process_message(err_req) {
    Some(resp) => ignore(client.handle_message(resp))
    None => fail("expected an error response")
  }
  match client.take_result(err_id) {
    Ok(_) => fail("expected an error result")
    Err(RpcError(_, _)) => assert_true(true)
    Err(_) => fail("expected an RpcError")
  }
}

///|
test "client take_result fails before any response arrives" {
  let client = Client::new("c", "1.0.0")
  match client.take_result(IdInt(99)) {
    Ok(_) => fail("expected an error for a missing response")
    Err(_) => assert_true(true)
  }
}

///|
test "client captures server-initiated notifications" {
  let client = Client::new("c", "1.0.0")
  let notif = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/tools/list_changed\"}"
  ignore(client.handle_message(notif))
  let received = client.received_notifications()
  assert_true(received.length() == 1)
  assert_true(received[0].method_str() == "notifications/tools/list_changed")
}
