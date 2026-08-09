///|
test "resource fluent builder encodes metadata" {
  let resource = Resource::new("file:///guide.md", "guide")
    .with_title("Guide")
    .describe("Project guide")
    .with_mime_type("text/markdown")
  let encoded = resource.to_json().stringify()
  assert_true(encoded.contains("file:///guide.md"))
  assert_true(encoded.contains("Guide"))
  assert_true(encoded.contains("Project guide"))
  assert_true(encoded.contains("text/markdown"))
}

///|
test "resource omits optional metadata by default" {
  let encoded = Resource::new("memory://empty", "empty").to_json().stringify()
  assert_true(encoded.contains("memory://empty"))
  assert_true(!encoded.contains("title"))
  assert_true(!encoded.contains("description"))
  assert_true(!encoded.contains("mimeType"))
}

///|
test "resource template builder uses protocol field names" {
  let template = ResourceTemplate::new("file:///{path}", "workspace-file")
    .with_title("Workspace file")
    .describe("Reads a workspace file")
    .with_mime_type("text/plain")
  let encoded = template.to_json().stringify()
  assert_true(encoded.contains("uriTemplate"))
  assert_true(encoded.contains("file:///{path}"))
  assert_true(encoded.contains("workspace-file"))
  assert_true(encoded.contains("text/plain"))
}

///|
test "resource read result supports several content values" {
  let result = ReadResourceResult::new([
    TextResourceContents("memory://a", Some("text/plain"), "alpha"),
    BlobResourceContents("memory://b", Some("application/octet-stream"), "AA=="),
  ])
  let encoded = result.to_json().stringify()
  assert_true(encoded.contains("alpha"))
  assert_true(encoded.contains("AA=="))
  assert_true(encoded.contains("blob"))
}

///|
test "prompt fluent builder describes arguments" {
  let prompt = Prompt::new("review")
    .with_title("Review code")
    .describe("Reviews a source file")
    .arg_desc("path", "Workspace-relative path", true)
    .arg("style", false)
  let encoded = prompt.to_json().stringify()
  assert_true(encoded.contains("Review code"))
  assert_true(encoded.contains("Workspace-relative path"))
  assert_true(encoded.contains("required\":true"))
  assert_true(encoded.contains("required\":false"))
}

///|
test "prompt messages encode user and assistant roles" {
  let result = GetPromptResult::new([
    PromptMessage::user("Please review this"),
    PromptMessage::assistant("I will review it"),
  ]).describe("Two-turn review")
  let encoded = result.to_json().stringify()
  assert_true(encoded.contains("Two-turn review"))
  assert_true(encoded.contains("user"))
  assert_true(encoded.contains("assistant"))
  assert_true(encoded.contains("Please review this"))
}

///|
test "server advertises all high-level capabilities" {
  let server = McpServer::new("all", "1.0")
  let request = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}"
  let response = server.process_message(request).unwrap()
  assert_true(response.contains("tools"))
  assert_true(response.contains("resources"))
  assert_true(response.contains("prompts"))
  assert_true(response.contains("listChanged"))
}

///|
test "server lists registered resources" {
  let server = McpServer::new("resource-server", "1.0")
  ignore(
    server.resource(Resource::new("memory://status", "status"), fn(uri) {
      ReadResourceResult::text(uri, "ready")
    }),
  )
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"resources/list\"}",
    )
    .unwrap()
  assert_true(response.contains("memory://status"))
  assert_true(response.contains("status"))
}

///|
test "server reads a registered resource" {
  let server = McpServer::new("resource-server", "1.0")
  ignore(
    server.resource(Resource::new("memory://status", "status"), fn(uri) {
      ReadResourceResult::text(uri, "ready")
    }),
  )
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"resources/read\",\"params\":{\"uri\":\"memory://status\"}}",
    )
    .unwrap()
  assert_true(response.contains("ready"))
  assert_true(response.contains("contents"))
}

///|
test "server rejects an unknown resource" {
  let server = McpServer::new("resource-server", "1.0")
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"resources/read\",\"params\":{\"uri\":\"memory://missing\"}}",
    )
    .unwrap()
  assert_true(response.contains("-32602"))
  assert_true(response.contains("resource: memory://missing"))
}

///|
test "server validates resource read parameters" {
  let server = McpServer::new("resource-server", "1.0")
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"resources/read\",\"params\":{}}",
    )
    .unwrap()
  assert_true(response.contains("-32602"))
}

///|
test "server lists registered prompts" {
  let server = McpServer::new("prompt-server", "1.0")
  ignore(
    server.prompt(Prompt::new("welcome").arg("name", true), fn(_args) {
      GetPromptResult::new([PromptMessage::user("Welcome")])
    }),
  )
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"prompts/list\"}",
    )
    .unwrap()
  assert_true(response.contains("welcome"))
  assert_true(response.contains("name"))
}

///|
test "server renders a registered prompt" {
  let server = McpServer::new("prompt-server", "1.0")
  ignore(
    server.prompt(Prompt::new("welcome"), fn(args) {
      GetPromptResult::new([PromptMessage::user("args=" + args.stringify())])
    }),
  )
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"prompts/get\",\"params\":{\"name\":\"welcome\",\"arguments\":{\"name\":\"Ada\"}}}",
    )
    .unwrap()
  assert_true(response.contains("Ada"))
  assert_true(response.contains("messages"))
}

///|
test "server rejects an unknown prompt" {
  let server = McpServer::new("prompt-server", "1.0")
  let response = server
    .process_message(
      "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"prompts/get\",\"params\":{\"name\":\"missing\"}}",
    )
    .unwrap()
  assert_true(response.contains("-32602"))
  assert_true(response.contains("prompt: missing"))
}

///|
test "client builds resource discovery requests" {
  let client = Client::new("client", "1.0")
  let (first, list) = client.build_resources_list(None)
  let (second, page) = client.build_resources_list(Some("cursor-2"))
  assert_eq(first, IdInt(1))
  assert_eq(second, IdInt(2))
  assert_true(list.contains("resources/list"))
  assert_true(!list.contains("cursor"))
  assert_true(page.contains("cursor-2"))
}

///|
test "client builds resource read and subscribe requests" {
  let client = Client::new("client", "1.0")
  let (_, read) = client.build_resources_read("file:///README.md")
  let (_, subscribe) = client.build_resources_subscribe("file:///README.md")
  assert_true(read.contains("resources/read"))
  assert_true(read.contains("file:///README.md"))
  assert_true(subscribe.contains("resources/subscribe"))
}

///|
test "client builds prompt discovery requests" {
  let client = Client::new("client", "1.0")
  let (_, list) = client.build_prompts_list(Some("next"))
  let args : Map[String, Json] = Map([])
  args["language"] = Json::string("MoonBit")
  let (_, get) = client.build_prompts_get("explain", Json::object(args))
  assert_true(list.contains("prompts/list"))
  assert_true(list.contains("next"))
  assert_true(get.contains("prompts/get"))
  assert_true(get.contains("MoonBit"))
}

///|
test "client builds logging level request" {
  let client = Client::new("client", "1.0")
  let (_, request) = client.build_logging_set_level(LevelWarning)
  assert_true(request.contains("logging/setLevel"))
  assert_true(request.contains("warning"))
}

///|
test "client initialized notification has no request id" {
  let client = Client::new("client", "1.0")
  let notification = client.build_initialized()
  assert_true(notification.contains("notifications/initialized"))
  assert_true(!notification.contains("\"id\""))
}

///|
test "connection sends resource requests through transport" {
  let client = Client::new("client", "1.0")
  let transport = BufferedTransport::new()
  let connection = ClientConnection::new(client, transport)
  assert_eq(connection.send_resources_list(None), IdInt(1))
  assert_eq(connection.send_resources_read("memory://x"), IdInt(2))
  assert_eq(connection.send_resources_subscribe("memory://x"), IdInt(3))
  let messages = transport.messages()
  assert_true(messages.length() == 3)
  assert_true(messages[0].contains("resources/list"))
  assert_true(messages[1].contains("resources/read"))
  assert_true(messages[2].contains("resources/subscribe"))
}

///|
test "connection sends prompt and logging requests through transport" {
  let client = Client::new("client", "1.0")
  let transport = BufferedTransport::new()
  let connection = ClientConnection::new(client, transport)
  assert_eq(connection.send_prompts_list(None), IdInt(1))
  assert_eq(
    connection.send_prompts_get("hello", Json::empty_object()),
    IdInt(2),
  )
  assert_eq(connection.send_logging_set_level(LevelDebug), IdInt(3))
  let messages = transport.messages()
  assert_true(messages.length() == 3)
  assert_true(messages[0].contains("prompts/list"))
  assert_true(messages[1].contains("prompts/get"))
  assert_true(messages[2].contains("logging/setLevel"))
}
