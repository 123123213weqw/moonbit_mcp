///|
test "error codes map parse errors" {
  assert_eq(ParseError("bad").to_code(), parse_error_code)
}

///|
test "error codes map protocol errors" {
  assert_eq(ProtocolError("bad").to_code(), invalid_request_code)
}

///|
test "error codes map unknown methods" {
  assert_eq(UnknownMethod("x").to_code(), method_not_found_code)
}

///|
test "error codes map invalid arguments" {
  assert_eq(InvalidArguments("x").to_code(), invalid_params_code)
}

///|
test "error codes map transport errors" {
  assert_eq(TransportError("x").to_code(), internal_error_code)
}

///|
test "error messages retain parse detail" {
  assert_eq(ParseError("bad token").to_message(), "Parse error: bad token")
}

///|
test "error messages retain protocol detail" {
  assert_eq(
    ProtocolError("bad state").to_message(),
    "Protocol error: bad state",
  )
}

///|
test "error messages identify unknown target" {
  assert_eq(UnknownTarget("tool: x").to_message(), "Unknown target: tool: x")
}

///|
test "all log levels use protocol spelling" {
  assert_eq(LevelDebug.to_string(), "debug")
  assert_eq(LevelInfo.to_string(), "info")
  assert_eq(LevelNotice.to_string(), "notice")
  assert_eq(LevelWarning.to_string(), "warning")
  assert_eq(LevelError.to_string(), "error")
  assert_eq(LevelCritical.to_string(), "critical")
  assert_eq(LevelAlert.to_string(), "alert")
  assert_eq(LevelEmergency.to_string(), "emergency")
}

///|
test "log message encodes logger and structured data" {
  let data : Map[String, Json] = Map([])
  data["requestId"] = Json::string("abc")
  let message : LogMessage = {
    level: LevelNotice,
    logger: Some("sdk"),
    data: Json::object(data),
  }
  let encoded = message.to_json().stringify()
  assert_true(encoded.contains("notice"))
  assert_true(encoded.contains("sdk"))
  assert_true(encoded.contains("requestId"))
}

///|
test "log message omits absent logger" {
  let message : LogMessage = {
    level: LevelInfo,
    logger: None,
    data: Json::string("ready"),
  }
  let encoded = message.to_json().stringify()
  assert_true(encoded.contains("ready"))
  assert_true(!encoded.contains("logger"))
}

///|
test "text content convenience constructor round trips" {
  assert_eq(text_content("hello").as_text(), Some("hello"))
}

///|
test "non-text content has no text projection" {
  let image = ImageContent("AA==", "image/png", None)
  assert_eq(image.as_text(), None)
}

///|
test "image content encodes base64 and media type" {
  let encoded = ImageContent("AA==", "image/png", None).to_json().stringify()
  assert_true(encoded.contains("image"))
  assert_true(encoded.contains("AA=="))
  assert_true(encoded.contains("image/png"))
}

///|
test "audio content encodes base64 and media type" {
  let encoded = AudioContent("AQ==", "audio/wav", None).to_json().stringify()
  assert_true(encoded.contains("audio"))
  assert_true(encoded.contains("AQ=="))
  assert_true(encoded.contains("audio/wav"))
}

///|
test "resource link encodes optional metadata" {
  let block = ResourceLink(
    "file:///a",
    "a",
    Some("A"),
    Some("Resource A"),
    Some("text/plain"),
    None,
  )
  let encoded = block.to_json().stringify()
  assert_true(encoded.contains("resource_link"))
  assert_true(encoded.contains("Resource A"))
  assert_true(encoded.contains("text/plain"))
}

///|
test "embedded text resource encodes content" {
  let block = EmbeddedResource(
    TextResourceContents("memory://a", Some("text/plain"), "alpha"),
    None,
  )
  let encoded = block.to_json().stringify()
  assert_true(encoded.contains("resource"))
  assert_true(encoded.contains("memory://a"))
  assert_true(encoded.contains("alpha"))
}

///|
test "embedded blob resource encodes content" {
  let block = EmbeddedResource(
    BlobResourceContents("memory://b", None, "AA=="),
    None,
  )
  let encoded = block.to_json().stringify()
  assert_true(encoded.contains("blob"))
  assert_true(encoded.contains("AA=="))
  assert_true(!encoded.contains("mimeType"))
}

///|
test "content block arrays preserve ordering" {
  let encoded = content_blocks_to_json([
    text_content("first"),
    text_content("second"),
  ]).stringify()
  assert_true(encoded.contains("first"))
  assert_true(encoded.contains("second"))
}

///|
test "schema description is emitted" {
  let encoded = JsonSchema::object()
    .describe("Input payload")
    .to_json()
    .stringify()
  assert_true(encoded.contains("Input payload"))
}

///|
test "schema numeric property kinds are distinct" {
  let encoded = JsonSchema::object()
    .number("ratio")
    .integer("count")
    .to_json()
    .stringify()
  assert_true(encoded.contains("ratio"))
  assert_true(encoded.contains("number"))
  assert_true(encoded.contains("count"))
  assert_true(encoded.contains("integer"))
}

///|
test "schema boolean properties are required" {
  let encoded = JsonSchema::object().boolean("force").to_json().stringify()
  assert_true(encoded.contains("boolean"))
  assert_true(encoded.contains("required"))
  assert_true(encoded.contains("force"))
}

///|
test "schema optional property is not required" {
  let encoded = JsonSchema::object()
    .optional_string("hint")
    .to_json()
    .stringify()
  assert_true(encoded.contains("hint"))
  assert_true(!encoded.contains("required"))
}

///|
test "schema required list accumulates fields" {
  let encoded = JsonSchema::object()
    .string("name")
    .integer("age")
    .boolean("active")
    .to_json()
    .stringify()
  assert_true(encoded.contains("\"name\""))
  assert_true(encoded.contains("\"age\""))
  assert_true(encoded.contains("\"active\""))
}

///|
test "tool description builder retains schema" {
  let tool = Tool::new("search", JsonSchema::object().string("query")).describe(
    "Search documents",
  )
  let encoded = tool.to_json().stringify()
  assert_true(encoded.contains("search"))
  assert_true(encoded.contains("Search documents"))
  assert_true(encoded.contains("query"))
}

///|
test "tool annotations have conservative defaults" {
  let annotations = ToolAnnotations::new()
  assert_eq(annotations.title, None)
  assert_true(!annotations.read_only_hint)
  assert_true(annotations.destructive_hint)
  assert_true(!annotations.idempotent_hint)
  assert_true(annotations.open_world_hint)
}

///|
test "tool list encoder emits every tool" {
  let encoded = tools_to_json([
    Tool::new("one", JsonSchema::object()),
    Tool::new("two", JsonSchema::object()),
  ]).stringify()
  assert_true(encoded.contains("one"))
  assert_true(encoded.contains("two"))
}

///|
test "successful call result contains text block" {
  let encoded = CallToolResult::text("ok").to_json().stringify()
  assert_true(encoded.contains("\"isError\":false"))
  assert_true(encoded.contains("\"type\":\"text\""))
  assert_true(encoded.contains("ok"))
}

///|
test "failed call result contains error text" {
  let encoded = CallToolResult::error("denied").to_json().stringify()
  assert_true(encoded.contains("\"isError\":true"))
  assert_true(encoded.contains("denied"))
}

///|
test "default capabilities encode to empty object" {
  assert_eq(ServerCapabilities::new().to_json().stringify(), "{}")
}

///|
test "resource capabilities encode both flags" {
  let capabilities = ServerCapabilities::new()
  capabilities.resources_subscribe = true
  capabilities.resources_list_changed = true
  let encoded = capabilities.to_json().stringify()
  assert_true(encoded.contains("subscribe\":true"))
  assert_true(encoded.contains("listChanged\":true"))
}

///|
test "logging capability encodes empty object" {
  let capabilities = ServerCapabilities::new()
  capabilities.logging = true
  assert_true(capabilities.to_json().stringify().contains("\"logging\":{}"))
}

///|
test "implementation omits absent title" {
  let implementation : Implementation = {
    name: "server",
    title: None,
    version: "1.2.3",
  }
  let encoded = implementation.to_json().stringify()
  assert_true(encoded.contains("server"))
  assert_true(encoded.contains("1.2.3"))
  assert_true(!encoded.contains("title"))
}

///|
test "pagination constructor starts without cursor" {
  let page = Paginated::new(["a", "b"])
  assert_eq(page.items, ["a", "b"])
  assert_eq(page.next_cursor, None)
}

///|
test "pagination cursor constructor retains items" {
  let page = Paginated::with_cursor([1, 2], "next-page")
  assert_eq(page.items, [1, 2])
  assert_eq(page.next_cursor, Some("next-page"))
}

///|
test "buffered transport close prevents later sends" {
  let transport = BufferedTransport::new()
  send_message(transport, "before")
  transport.close()
  send_message(transport, "after")
  let messages = transport.messages()
  assert_eq(messages, ["before"])
}

///|
test "in-memory transport close prevents delivery" {
  let (sender, receiver) = InMemoryTransport::pair()
  let received : Array[String] = []
  receiver.on_message(fn(value) { received.push(value) })
  sender.close()
  send_message(sender, "ignored")
  assert_true(received.is_empty())
}

///|
test "send and return preserves transport value" {
  let transport = BufferedTransport::new()
  let returned = send_and_return(transport, "message")
  assert_eq(returned.messages(), ["message"])
}

///|
test "server custom handler receives missing params as null" {
  let server = Server::new("s", "1")
  ignore(
    server.handle_method("inspect", fn(params, _context) {
      let result : Map[String, Json] = Map([])
      result["wasNull"] = Json::boolean(params == Json::null())
      Ok(Json::object(result))
    }),
  )
  let response = server
    .process_message("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"inspect\"}")
    .unwrap()
  assert_true(response.contains("wasNull\":true"))
}

///|
test "server custom handler error becomes rpc error" {
  let server = Server::new("s", "1")
  ignore(
    server.handle_method("fail", fn(_params, _context) {
      Err(InvalidArguments("expected field"))
    }),
  )
  let response = server
    .process_message("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"fail\"}")
    .unwrap()
  assert_true(response.contains("-32602"))
  assert_true(response.contains("expected field"))
}

///|
test "message buffer handles a byte at a time" {
  let buffer = MessageBuffer::new()
  let output : Array[String] = []
  for byte in "one\ntwo\n" {
    buffer.feed(byte.to_string(), fn(line) { output.push(line) })
  }
  assert_eq(output, ["one", "two"])
}

///|
test "message buffer accepts mixed line endings" {
  let buffer = MessageBuffer::new()
  let output = buffer.push("one\r\ntwo\nthree\r\n")
  assert_eq(output, ["one", "two", "three"])
}
