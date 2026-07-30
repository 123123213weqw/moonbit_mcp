///|
/// Build the echo server: a single `echo` tool that returns its message.
fn build_server() -> @mcp.Server {
  let mcp = @mcp.McpServer::new("echo-server", "0.4.0")
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
/// Read one byte from stdin, or -1 at end-of-file.
#cfg(target="native")
extern "C" fn c_getchar() -> Int = "getchar"

///|
/// Dispatch one framed message to the server, printing any response to stdout.
#cfg(target="native")
fn respond(server : @mcp.Server, line : String) -> Unit {
  match server.process_message(line) {
    Some(resp) => println(resp)
    None => ()
  }
}

///|
/// Decode an accumulated line of stdin bytes as UTF-8.
#cfg(target="native")
fn decode_line(line : Array[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(line))
}

///|
/// Native entry point: read newline-delimited JSON-RPC from stdin and write
/// each response back to stdout.
#cfg(target="native")
fn main {
  let server = build_server()
  let mut line : Array[Byte] = []
  let mut c = c_getchar()
  while c != -1 {
    if c == 10 {
      respond(server, decode_line(line))
      line = []
    } else {
      line.push(c.to_byte())
    }
    c = c_getchar()
  }
  if line.length() > 0 {
    respond(server, decode_line(line))
  }
}

///|
/// Non-native targets have no stdin; run the server in memory as a demo.
#cfg(not(target="native"))
fn main {
  let server = build_server()
  let init = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"demo\",\"version\":\"0.0.0\"}}}"
  match server.process_message(init) {
    Some(resp) => println(resp)
    None => ()
  }
  // Round-trip the banner through UTF-8 so the encoding import stays live on
  // every target (this binary is only really useful on native, where it has a
  // stdin to read from).
  let banner = "stdio needs the native target: moon run cmd/mcp-echo --target native"
  println(@utf8.decode_lossy(@utf8.encode(banner)))
}
