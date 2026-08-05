///|
/// Wires a [Client] to a byte stream via a [Transport].
///
/// Outbound requests are built by the client and sent through the transport
/// ([ClientConnection::send_initialize] and friends); inbound chunks are fed to
/// [ClientConnection::receive], framed by an internal [MessageBuffer], and each
/// complete JSON-RPC message is handed to [Client::handle_message] for response
/// correlation. This is the client-side mirror of [ServerConnection]: together
/// the two can drive a full MCP session over any byte stream.
pub(all) struct ClientConnection[T] {
  client : Client
  transport : T
  buffer : MessageBuffer
}

///|
/// Create a connection driving the given client and sending requests through
/// the transport.
pub fn[T] ClientConnection::new(
  client : Client,
  transport : T,
) -> ClientConnection[T] {
  { client, transport, buffer: MessageBuffer::new() }
}

///|
/// Feed an inbound chunk. Every complete message it yields is handed to
/// [Client::handle_message]. Malformed lines are skipped here; drive
/// [Client::handle_message] directly to surface parse errors.
pub fn[T] ClientConnection::receive(
  self : ClientConnection[T],
  chunk : String,
) -> Unit {
  let client = self.client
  self.buffer.feed(chunk, fn(line) { ignore(client.handle_message(line)) })
}

///|
/// Dispatch a single, already-complete message line (no framing needed).
pub fn[T] ClientConnection::receive_line(
  self : ClientConnection[T],
  line : String,
) -> Result[Unit, McpError] {
  self.client.handle_message(line)
}

///|
/// Whether a partial inbound message is still buffered awaiting more bytes.
pub fn[T] ClientConnection::has_pending(self : ClientConnection[T]) -> Bool {
  self.buffer.has_pending()
}

///|
/// Send a raw outbound message (e.g. `notifications/initialized`) through the
/// transport.
pub fn[T : Transport] ClientConnection::send_raw(
  self : ClientConnection[T],
  msg : String,
) -> Unit {
  send_message(self.transport, msg)
}

///|
/// Build a request with the client and send it through the transport; returns
/// the assigned id so the caller can correlate the response via
/// [Client::take_result].
pub fn[T : Transport] ClientConnection::send_request(
  self : ClientConnection[T],
  method_name : String,
  params : Json?,
) -> RequestId {
  let (id, req) = self.client.build_request(method_name, params)
  send_message(self.transport, req)
  id
}

///|
/// Build and send the `initialize` request; returns its id. Feed the response
/// back via [ClientConnection::receive], then finish the handshake with
/// [ClientConnection::take_initialize].
pub fn[T : Transport] ClientConnection::send_initialize(
  self : ClientConnection[T],
) -> RequestId {
  let (id, req) = self.client.build_initialize()
  send_message(self.transport, req)
  id
}

///|
/// Build and send the `notifications/initialized` notification that completes
/// the MCP session setup after a successful initialize response.
pub fn[T : Transport] ClientConnection::send_initialized(
  self : ClientConnection[T],
) -> Unit {
  send_message(
    self.transport,
    message_to_string(
      MsgNotification({ method_name: method_initialized, params: None }),
    ),
  )
}

///|
/// Build and send a `ping` request; returns its id.
pub fn[T : Transport] ClientConnection::send_ping(
  self : ClientConnection[T],
) -> RequestId {
  let (id, req) = self.client.build_ping()
  send_message(self.transport, req)
  id
}

///|
/// Build and send a `tools/list` request; returns its id.
pub fn[T : Transport] ClientConnection::send_tools_list(
  self : ClientConnection[T],
) -> RequestId {
  let (id, req) = self.client.build_tools_list()
  send_message(self.transport, req)
  id
}

///|
/// Build and send a `tools/call` request for the named tool; returns its id.
pub fn[T : Transport] ClientConnection::send_tools_call(
  self : ClientConnection[T],
  name : String,
  arguments : Json,
) -> RequestId {
  let (id, req) = self.client.build_tools_call(name, arguments)
  send_message(self.transport, req)
  id
}

///|
/// Complete the initialize handshake from the response stored for `id` (fed in
/// earlier via [ClientConnection::receive]). Records the server's
/// [Implementation] and the negotiated protocol version on the client.
pub fn[T] ClientConnection::take_initialize(
  self : ClientConnection[T],
  id : RequestId,
) -> Result[Implementation, McpError] {
  let result = match self.client.take_result(id) {
    Ok(r) => r
    Err(e) => return Err(e)
  }
  self.client.complete_initialize_result(result)
}
