///|
test "framing yields a single complete line" {
  let buf = MessageBuffer::new()
  let lines = buf.push("{\"jsonrpc\":\"2.0\"}\n")
  assert_true(lines.length() == 1)
  assert_true(lines[0] == "{\"jsonrpc\":\"2.0\"}")
  assert_true(!buf.has_pending())
}

///|
test "framing yields multiple lines from one chunk" {
  let buf = MessageBuffer::new()
  let lines = buf.push("a\nb\nc\n")
  assert_true(lines.length() == 3)
  assert_true(lines[0] == "a")
  assert_true(lines[1] == "b")
  assert_true(lines[2] == "c")
}

///|
test "framing buffers a partial line across pushes" {
  let buf = MessageBuffer::new()
  let first = buf.push("{\"jsonrpc\":")
  assert_true(first.length() == 0)
  assert_true(buf.has_pending())
  let second = buf.push("\"2.0\"}\n")
  assert_true(second.length() == 1)
  assert_true(second[0] == "{\"jsonrpc\":\"2.0\"}")
  assert_true(!buf.has_pending())
}

///|
test "framing strips CRLF carriage returns" {
  let buf = MessageBuffer::new()
  let lines = buf.push("ping\r\npong\r\n")
  assert_true(lines.length() == 2)
  assert_true(lines[0] == "ping")
  assert_true(lines[1] == "pong")
}

///|
test "framing keeps an unterminated tail pending" {
  let buf = MessageBuffer::new()
  let lines = buf.push("complete\npartial")
  assert_true(lines.length() == 1)
  assert_true(lines[0] == "complete")
  assert_true(buf.has_pending())
}

///|
test "framing feed delivers each line to a handler" {
  let buf = MessageBuffer::new()
  let got : Array[String] = []
  buf.feed("x\ny\n", fn(line) { got.push(line) })
  assert_true(got.length() == 2)
  assert_true(got[0] == "x")
  assert_true(got[1] == "y")
}

///|
test "framing an empty chunk yields nothing" {
  let buf = MessageBuffer::new()
  let lines = buf.push("")
  assert_true(lines.length() == 0)
  assert_true(!buf.has_pending())
}

///|
test "framing drives a server from a chunked stream" {
  let server = Server::new("s", "1.0")
  let buf = MessageBuffer::new()
  let responses : Array[String] = []
  let handle = fn(line : String) {
    match server.process_message(line) {
      Some(r) => responses.push(r)
      None => ()
    }
  }
  // Two ping requests, split mid-message across two arbitrary chunks.
  let chunk_a = "{\"jsonrpc\":\"2.0\",\"id\":1,\"me"
  let chunk_b = "thod\":\"ping\"}\n{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"ping\"}\n"
  buf.feed(chunk_a, handle)
  assert_true(responses.length() == 0)
  buf.feed(chunk_b, handle)
  assert_true(responses.length() == 2)
  assert_true(!buf.has_pending())
}
