///|
test "initialize preserves string response identifier" {
  let server = Server::new("server", "1.0")
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":\"init-1\",\"method\":\"initialize\",\"params\":{}}",
    )
    .unwrap()
  assert_true(response.contains("\"id\":\"init-1\""))
  assert_true(response.contains("\"protocolVersion\":\"2025-06-18\""))
}

///|
test "server initialization state changes only on notification" {
  let server = Server::new("server", "1.0")
  ignore(
    server.process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}",
    ),
  )
  assert_true(!server.initialized)
  ignore(
    server.process_message(
      "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}",
    ),
  )
  assert_true(server.initialized)
}

///|
test "unrelated notification does not initialize server" {
  let server = Server::new("server", "1.0")
  ignore(
    server.process_message(
      "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/message\",\"params\":{}}",
    ),
  )
  assert_true(!server.initialized)
}

///|
test "client rejects initialize error response" {
  let client = Client::new("client", "1.0")
  match
    client.complete_initialize(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32602,\"message\":\"version rejected\"}}",
    ) {
    Err(RpcError(code, message)) => {
      assert_eq(code, -32602)
      assert_eq(message, "version rejected")
    }
    _ => fail("expected initialize RPC error")
  }
  assert_true(!client.is_initialized())
}

///|
test "client rejects initialize response without version" {
  let client = Client::new("client", "1.0")
  match
    client.complete_initialize(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"serverInfo\":{\"name\":\"s\",\"version\":\"1\"}}}",
    ) {
    Err(ProtocolError(message)) =>
      assert_true(message.contains("protocolVersion"))
    _ => fail("expected missing version error")
  }
}

///|
test "client rejects initialize server info without name" {
  let client = Client::new("client", "1.0")
  match
    client.complete_initialize(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\",\"serverInfo\":{\"version\":\"1\"}}}",
    ) {
    Err(ProtocolError(message)) => assert_true(message.contains("name"))
    _ => fail("expected missing name error")
  }
}

///|
test "client accepts omitted server version as empty" {
  let client = Client::new("client", "1.0")
  let info = client
    .complete_initialize(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\",\"serverInfo\":{\"name\":\"s\"}}}",
    )
    .unwrap()
  assert_eq(info.name, "s")
  assert_eq(info.version, "")
}

///|
test "generic client request supports array params" {
  let client = Client::new("client", "1.0")
  let (id, encoded) = client.build_request(
    "experimental/sum",
    Some(Json::array([Json::number(1.0), Json::number(2.0)])),
  )
  assert_eq(id, IdInt(1))
  assert_true(encoded.contains("experimental/sum"))
  assert_true(encoded.contains("[1,2]"))
}

///|
test "generic client notification preserves object params" {
  let client = Client::new("client", "1.0")
  let params : Map[String, Json] = Map([])
  params["reason"] = Json::string("cancelled")
  let encoded = client.build_notification(
    "notifications/cancelled",
    Some(Json::object(params)),
  )
  assert_true(encoded.contains("notifications/cancelled"))
  assert_true(encoded.contains("cancelled"))
  assert_true(!encoded.contains("\"id\""))
}

///|
test "strict parser accepts array request params" {
  match
    parse_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"x\",\"params\":[1,2]}",
    ) {
    Ok(MsgRequest(request)) =>
      match request.params {
        Some(Array(values)) => assert_true(values.length() == 2)
        _ => fail("expected array params")
      }
    _ => fail("expected request")
  }
}

///|
test "strict parser rejects scalar request params" {
  match
    parse_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"x\",\"params\":true}",
    ) {
    Err(ParseError(message)) => assert_true(message.contains("params"))
    _ => fail("expected params parse error")
  }
}

///|
test "strict parser rejects a response with both outcomes" {
  match
    parse_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{},\"error\":{\"code\":-1,\"message\":\"bad\"}}",
    ) {
    Err(ParseError(message)) => assert_true(message.contains("both"))
    _ => fail("expected mutually exclusive outcome error")
  }
}

///|
test "strict parser rejects response without an outcome" {
  match parse_message("{\"jsonrpc\":\"2.0\",\"id\":1}") {
    Err(ParseError(message)) => assert_true(message.contains("result or error"))
    _ => fail("expected missing outcome error")
  }
}

///|
test "strict parser rejects fractional error code" {
  match
    parse_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32000.5,\"message\":\"bad\"}}",
    ) {
    Err(ParseError(message)) => assert_true(message.contains("integer"))
    _ => fail("expected fractional code error")
  }
}

///|
test "connection keeps working after malformed framed line" {
  let output = BufferedTransport::new()
  let connection = ServerConnection::new(Server::new("s", "1"), output)
  connection.receive(
    "not-json\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"ping\"}\n",
  )
  let messages = output.messages()
  assert_true(messages.length() == 2)
  assert_true(messages[0].contains("-32700"))
  assert_true(messages[1].contains("\"id\":2"))
}
