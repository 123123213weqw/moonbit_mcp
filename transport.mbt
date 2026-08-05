///|
/// Transport abstraction: how JSON-RPC messages enter and leave a server/client.
///
/// The trait only requires [send]. [start] and [close] are provided as
/// default no-ops so transports that do not need them (e.g. in-memory) incur
/// no boilerplate.
pub trait Transport {
  fn send(Self, String) -> Unit
}

///|
/// The callback invoked when a complete JSON-RPC message line arrives.
pub type MessageHandler = (String) -> Unit

///|
/// An in-memory transport pair for tests and same-process use.
///
/// Create a linked pair with [InMemoryTransport::pair]; messages sent on one
/// end are delivered to the handler of the other.
pub(all) struct InMemoryTransport {
  mut handler : MessageHandler?
  mut closed : Bool
  mut peer : InMemoryTransport?
}

///|
/// Create a linked pair of in-memory transports. Messages sent on one are
/// delivered to the other's handler.
pub fn InMemoryTransport::pair() -> (InMemoryTransport, InMemoryTransport) {
  let a : InMemoryTransport = { handler: None, closed: false, peer: None }
  let b : InMemoryTransport = { handler: None, closed: false, peer: None }
  a.peer = Some(b)
  b.peer = Some(a)
  (a, b)
}

///|
/// Set the message handler for this transport.
pub fn InMemoryTransport::on_message(
  self : InMemoryTransport,
  h : MessageHandler,
) -> Unit {
  self.handler = Some(h)
}

///|
/// Close the transport (subsequent sends are dropped).
pub fn InMemoryTransport::close(self : InMemoryTransport) -> Unit {
  self.closed = true
}

///|
pub impl Transport for InMemoryTransport with fn send(self, msg : String) -> Unit {
  if self.closed {
    return
  }
  match self.peer {
    Some(p) =>
      match p.handler {
        Some(h) => h(msg)
        None => ()
      }
    None => ()
  }
}

///|
/// A buffered transport that collects sent messages in an array (useful for testing).
pub(all) struct BufferedTransport {
  mut sent : Array[String]
  mut closed : Bool
}

///|
pub fn BufferedTransport::new() -> BufferedTransport {
  { sent: [], closed: false }
}

///|
/// Messages collected so far (in send order).
pub fn BufferedTransport::messages(self : BufferedTransport) -> Array[String] {
  self.sent
}

///|
pub fn BufferedTransport::close(self : BufferedTransport) -> Unit {
  self.closed = true
}

///|
pub impl Transport for BufferedTransport with fn send(self, msg : String) -> Unit {
  if !self.closed {
    self.sent.push(msg)
  }
}

///|
/// Send a message through any transport (generic helper for trait dispatch).
pub fn[T : Transport] send_message(t : T, msg : String) -> Unit {
  T::send(t, msg)
}

///|
/// Send a message through any transport and return the transport (for chaining).
pub fn[T : Transport] send_and_return(t : T, msg : String) -> T {
  T::send(t, msg)
  t
}

///|
test "in-memory transport send via trait" {
  let (a, b) = InMemoryTransport::pair()
  let mut received = ""
  b.on_message(fn(s) { received = s })
  send_message(a, "hello")
  assert_true(received == "hello")
}

///|
test "buffered transport send via trait" {
  let t = BufferedTransport::new()
  send_message(t, "msg1")
  send_message(t, "msg2")
  assert_true(t.messages().length() == 2)
}
