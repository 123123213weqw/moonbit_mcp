///|
fn expect_parse_error(raw : String) -> Unit raise Failure {
  match parse_message(raw) {
    Err(_) => ()
    Ok(_) => fail("expected parse failure: " + raw)
  }
}

///|
fn expect_request(
  raw : String,
  expected_method : String,
) -> RpcRequest raise Failure {
  match parse_message(raw) {
    Ok(MsgRequest(req)) => {
      if req.method_str() != expected_method {
        fail("unexpected request method")
      }
      req
    }
    _ => fail("expected request: " + raw)
  }
}

///|
test "conformance accepts integer request ids" {
  let req = expect_request(
    "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"ping\"}", "ping",
  )
  assert_eq(req.id, IdInt(0))
}

///|
test "conformance accepts negative integer request ids" {
  let req = expect_request(
    "{\"jsonrpc\":\"2.0\",\"id\":-7,\"method\":\"ping\"}", "ping",
  )
  assert_eq(req.id, IdInt(-7))
}

///|
test "conformance accepts string request ids" {
  let req = expect_request(
    "{\"jsonrpc\":\"2.0\",\"id\":\"job-42\",\"method\":\"ping\"}", "ping",
  )
  assert_eq(req.id, IdString("job-42"))
}

///|
test "conformance preserves empty string ids" {
  let req = expect_request(
    "{\"jsonrpc\":\"2.0\",\"id\":\"\",\"method\":\"ping\"}", "ping",
  )
  assert_eq(req.id, IdString(""))
}

///|
test "conformance rejects fractional request ids" {
  expect_parse_error("{\"jsonrpc\":\"2.0\",\"id\":1.5,\"method\":\"ping\"}")
}

///|
test "conformance rejects boolean request ids" {
  expect_parse_error("{\"jsonrpc\":\"2.0\",\"id\":true,\"method\":\"ping\"}")
}

///|
test "conformance rejects null request ids" {
  expect_parse_error("{\"jsonrpc\":\"2.0\",\"id\":null,\"method\":\"ping\"}")
}

///|
test "conformance rejects wrong jsonrpc version" {
  expect_parse_error("{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"ping\"}")
}

///|
test "conformance rejects missing jsonrpc version" {
  expect_parse_error("{\"id\":1,\"method\":\"ping\"}")
}

///|
test "conformance rejects a non-string method" {
  expect_parse_error("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":7}")
}

///|
test "conformance rejects a top-level array" {
  expect_parse_error("[]")
}

///|
test "conformance rejects a top-level scalar" {
  expect_parse_error("42")
}

///|
test "conformance rejects truncated json" {
  expect_parse_error("{\"jsonrpc\":\"2.0\"")
}

///|
test "conformance classifies id-less messages as notifications" {
  let raw = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/progress\",\"params\":{\"progress\":0.5}}"
  match parse_message(raw) {
    Ok(MsgNotification(notification)) => {
      assert_eq(notification.method_str(), "notifications/progress")
      assert_true(
        message_to_string(MsgNotification(notification)).contains("0.5"),
      )
    }
    _ => fail("expected notification")
  }
}

///|
test "conformance round trips nested params" {
  let raw = "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"sum\",\"arguments\":{\"values\":[1,2,3]}}}"
  let req = expect_request(raw, "tools/call")
  let encoded = message_to_string(MsgRequest(req))
  assert_true(encoded.contains("values"))
  assert_true(encoded.contains("[1,2,3]"))
}

///|
test "conformance result response keeps null payload" {
  let raw = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
  match parse_message(raw) {
    Ok(MsgResponse(RpcResult(IdInt(1), Null))) => assert_true(true)
    _ => fail("expected null result")
  }
}

///|
test "conformance error response keeps optional data" {
  let raw = "{\"jsonrpc\":\"2.0\",\"id\":3,\"error\":{\"code\":-32001,\"message\":\"busy\",\"data\":{\"retryAfter\":2}}}"
  match parse_message(raw) {
    Ok(MsgResponse(RpcErrorResp(_, error))) => {
      assert_eq(error.code, -32001)
      assert_eq(error.message, "busy")
      match error.data {
        Some(data) => assert_true(data.stringify().contains("retryAfter"))
        None => fail("expected error data")
      }
    }
    _ => fail("expected error response")
  }
}

///|
test "conformance rejects error response without code" {
  expect_parse_error(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"message\":\"bad\"}}",
  )
}

///|
test "conformance rejects error response without message" {
  expect_parse_error("{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-1}}")
}

///|
test "conformance escapes strings during encoding" {
  let request : RpcRequest = {
    id: IdString("quoted\"id"),
    method_name: "x/y",
    params: Some(Json::string("line1\nline2")),
  }
  let encoded = message_to_string(MsgRequest(request))
  assert_true(encoded.contains("quoted\\\"id"))
  assert_true(encoded.contains("line1\\nline2"))
}

///|
test "server returns parse error code for malformed json" {
  let response = Server::new("s", "1").process_message("not-json").unwrap()
  assert_true(response.contains("-32700"))
  assert_true(response.contains("Parse error"))
}

///|
test "server returns method not found with original request id" {
  let response = Server::new("s", "1")
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":\"abc\",\"method\":\"unknown\"}",
    )
    .unwrap()
  assert_true(response.contains("-32601"))
  assert_true(response.contains("\"id\":\"abc\""))
}

///|
test "server ping has an empty object result" {
  let response = Server::new("s", "1")
    .process_message("{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"ping\"}")
    .unwrap()
  assert_true(response.contains("\"id\":12"))
  assert_true(response.contains("\"result\":{}"))
}

///|
test "server ignores inbound responses" {
  let response = Server::new("s", "1").process_message(
    "{\"jsonrpc\":\"2.0\",\"id\":12,\"result\":{}}",
  )
  assert_eq(response, None)
}

///|
test "client correlates out-of-order responses" {
  let client = Client::new("c", "1")
  let (first, _) = client.build_ping()
  let (second, _) = client.build_ping()
  ignore(
    client.handle_message(
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"order\":2}}",
    ),
  )
  ignore(
    client.handle_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"order\":1}}",
    ),
  )
  assert_true(client.take_result(first).unwrap().stringify().contains("1"))
  assert_true(client.take_result(second).unwrap().stringify().contains("2"))
}

///|
test "client removes a result after it is consumed" {
  let client = Client::new("c", "1")
  let (id, _) = client.build_ping()
  ignore(client.handle_message("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}"))
  ignore(client.take_result(id).unwrap())
  match client.take_result(id) {
    Err(ProtocolError(_)) => assert_true(true)
    _ => fail("expected consumed result to be absent")
  }
}

///|
test "client surfaces exact remote error code" {
  let client = Client::new("c", "1")
  let (id, _) = client.build_ping()
  ignore(
    client.handle_message(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":-32099,\"message\":\"overloaded\"}}",
    ),
  )
  match client.take_result(id) {
    Err(RpcError(code, message)) => {
      assert_eq(code, -32099)
      assert_eq(message, "overloaded")
    }
    _ => fail("expected remote error")
  }
}

///|
test "initialize rejects missing server info" {
  let client = Client::new("c", "1")
  match
    client.complete_initialize(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\"}}",
    ) {
    Err(ProtocolError(_)) => assert_true(true)
    _ => fail("expected protocol error")
  }
}

///|
test "initialize accepts an optional implementation title" {
  let client = Client::new("c", "1")
  let info = client
    .complete_initialize(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-06-18\",\"serverInfo\":{\"name\":\"s\",\"title\":\"Server\",\"version\":\"2\"}}}",
    )
    .unwrap()
  assert_eq(info.title, Some("Server"))
  assert_eq(info.version, "2")
}

///|
test "message framing preserves json whitespace" {
  let buffer = MessageBuffer::new()
  let messages = buffer.push("  { \"jsonrpc\" : \"2.0\" }  \n")
  assert_true(messages.length() == 1)
  assert_true(messages[0].contains("jsonrpc"))
}

///|
test "message framing yields empty records for consecutive newlines" {
  let buffer = MessageBuffer::new()
  let messages = buffer.push("a\n\nb\n")
  assert_true(messages.length() == 3)
  assert_eq(messages[0], "a")
  assert_eq(messages[1], "")
  assert_eq(messages[2], "b")
}
