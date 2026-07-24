///|
test "json-rpc request parse and encode round-trip" {
  let raw = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{\"cursor\":\"abc\"}}"
  match parse_message(raw) {
    Ok(MsgRequest(req)) => {
      assert_true(req.method_str() == "tools/list")
      match req.id {
        IdInt(n) => assert_true(n == 1)
        _ => fail("expected IdInt")
      }
      // round-trip encode
      let re = message_to_string(MsgRequest(req))
      // re should contain the same method and id
      assert_true(re.contains("tools/list"))
    }
    _ => fail("expected MsgRequest")
  }
}

///|
test "json-rpc notification parse" {
  let raw = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"
  match parse_message(raw) {
    Ok(MsgNotification(notif)) =>
      assert_true(notif.method_str() == "notifications/initialized")
    _ => fail("expected MsgNotification")
  }
}

///|
test "json-rpc response parse (result)" {
  let raw = "{\"jsonrpc\":\"2.0\",\"id\":42,\"result\":{\"tools\":[]}}"
  match parse_message(raw) {
    Ok(MsgResponse(RpcResult(id, _))) =>
      match id {
        IdInt(n) => assert_true(n == 42)
        _ => fail("expected IdInt")
      }
    _ => fail("expected MsgResponse RpcResult")
  }
}

///|
test "json-rpc response parse (error)" {
  let raw = "{\"jsonrpc\":\"2.0\",\"id\":\"abc\",\"error\":{\"code\":-32601,\"message\":\"not found\"}}"
  match parse_message(raw) {
    Ok(MsgResponse(RpcErrorResp(id, err))) => {
      match id {
        IdString(s) => assert_true(s == "abc")
        _ => fail("expected IdString")
      }
      assert_true(err.code == -32601)
      assert_true(err.message == "not found")
    }
    _ => fail("expected MsgResponse RpcErrorResp")
  }
}

///|
test "content block text encode" {
  let block = text_content("hello world")
  let j = block.to_json()
  let s = j.stringify()
  assert_true(s.contains("\"text\":\"hello world\""))
  assert_true(s.contains("\"type\":\"text\""))
}

///|
test "schema builder" {
  let schema = JsonSchema::object()
    |> JsonSchema::string_desc("name", "User name")
    |> JsonSchema::integer("age")
  let j = schema.to_json()
  let s = j.stringify()
  assert_true(s.contains("\"type\":\"object\""))
  assert_true(s.contains("\"name\""))
  assert_true(s.contains("\"age\""))
  assert_true(s.contains("\"required\""))
}

///|
test "tool encode" {
  let schema = JsonSchema::object() |> JsonSchema::string("message")
  let tool = Tool::new("echo", schema)
  let j = tool.to_json()
  let s = j.stringify()
  assert_true(s.contains("\"name\":\"echo\""))
  assert_true(s.contains("\"inputSchema\""))
}

///|
test "call tool result text" {
  let result = CallToolResult::text("done")
  let j = result.to_json()
  let s = j.stringify()
  assert_true(s.contains("\"content\""))
  assert_true(s.contains("\"isError\":false"))
}

///|
test "call tool result error" {
  let result = CallToolResult::error("failed")
  let j = result.to_json()
  let s = j.stringify()
  assert_true(s.contains("\"isError\":true"))
}

///|
test "server initialize handshake" {
  let server = Server::new("test-server", "1.0.0")
  let init_req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}"
  match server.process_message(init_req) {
    Some(resp) => {
      assert_true(resp.contains("test-server"))
      assert_true(resp.contains("2025-06-18"))
    }
    None => fail("expected a response")
  }
}

///|
test "server ping" {
  let server = Server::new("s", "1.0")
  let ping = "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"ping\"}"
  match server.process_message(ping) {
    Some(resp) => assert_true(resp.contains("5"))
    None => fail("expected ping response")
  }
}

///|
test "server unknown method" {
  let server = Server::new("s", "1.0")
  let req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"bogus/method\"}"
  match server.process_message(req) {
    Some(resp) => assert_true(resp.contains("-32601"))
    None => fail("expected error response")
  }
}

///|
test "server notification no response" {
  let server = Server::new("s", "1.0")
  let notif = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"
  match server.process_message(notif) {
    Some(_) => fail("notification should not produce a response")
    None => assert_true(server.initialized)
  }
}

///|
test "mcp server tool registration and list" {
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
  // list tools
  let list_req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}"
  match server.process_message(list_req) {
    Some(resp) => assert_true(resp.contains("echo"))
    None => fail("expected tools list response")
  }
  // call tool
  let call_req = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{\"message\":\"hi\"}}}"
  match server.process_message(call_req) {
    Some(resp) => {
      assert_true(resp.contains("hi"))
      assert_true(resp.contains("isError\":false"))
    }
    None => fail("expected tools/call response")
  }
}

///|
test "in-memory transport pair" {
  let (a, b) = InMemoryTransport::pair()
  let mut received = ""
  b.on_message(fn(s) { received = s })
  send_message(a, "hello")
  assert_true(received == "hello")
}

///|
test "buffered transport collects messages" {
  let t = BufferedTransport::new()
  send_message(t, "msg1")
  send_message(t, "msg2")
  let msgs = t.messages()
  assert_true(msgs.length() == 2)
  assert_true(msgs[0] == "msg1")
  assert_true(msgs[1] == "msg2")
}

///|
test "log level to string" {
  assert_true(LevelInfo.to_string() == "info")
  assert_true(LevelError.to_string() == "error")
  assert_true(LevelDebug.to_string() == "debug")
}

///|
test "capabilities to json" {
  let caps = ServerCapabilities::new()
  caps.tools_list_changed = true
  let j = caps.to_json()
  let s = j.stringify()
  assert_true(s.contains("tools"))
  assert_true(s.contains("listChanged"))
}

///|
test "implementation to json" {
  let impl_info : Implementation = {
    name: "my-server",
    title: Some("My Server"),
    version: "2.0.0",
  }
  let j = impl_info.to_json()
  let s = j.stringify()
  assert_true(s.contains("my-server"))
  assert_true(s.contains("My Server"))
  assert_true(s.contains("2.0.0"))
}
