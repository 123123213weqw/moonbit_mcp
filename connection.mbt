///|
/// Wires a [Server] to a byte stream via a [Transport].
///
/// Feed arbitrary inbound chunks to [ServerConnection::receive]; complete
/// JSON-RPC messages are framed by an internal [MessageBuffer], dispatched to
/// the server, and any responses are sent back out through the transport. This
/// is what turns the request/response core into a runnable stdio or HTTP
/// server — the transport supplies the actual I/O.
pub(all) struct ServerConnection[T] {
  server : Server
  transport : T
  buffer : MessageBuffer
}

///|
/// Create a connection dispatching to the given server and sending responses
/// through the transport. For a high-level [McpServer], pass `mcp.inner()`.
pub fn[T] ServerConnection::new(
  server : Server,
  transport : T,
) -> ServerConnection[T] {
  { server, transport, buffer: MessageBuffer::new() }
}

///|
/// Feed an inbound chunk. Every complete message it yields is dispatched to the
/// server; each response (requests only — notifications produce none) is sent
/// back out through the transport.
pub fn[T : Transport] ServerConnection::receive(
  self : ServerConnection[T],
  chunk : String,
) -> Unit {
  let server = self.server
  let transport = self.transport
  self.buffer.feed(chunk, fn(line) {
    match server.process_message(line) {
      Some(resp) => send_message(transport, resp)
      None => ()
    }
  })
}

///|
/// Dispatch a single, already-complete message line (no framing needed) and
/// send any response through the transport.
pub fn[T : Transport] ServerConnection::receive_line(
  self : ServerConnection[T],
  line : String,
) -> Unit {
  match self.server.process_message(line) {
    Some(resp) => send_message(self.transport, resp)
    None => ()
  }
}

///|
/// Whether a partial inbound message is still buffered awaiting more bytes.
pub fn[T] ServerConnection::has_pending(self : ServerConnection[T]) -> Bool {
  self.buffer.has_pending()
}
