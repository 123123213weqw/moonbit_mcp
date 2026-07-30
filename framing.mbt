///|
/// Accumulates inbound text and splits it into complete newline-delimited
/// JSON-RPC messages.
///
/// MCP's stdio and streamable-HTTP transports frame messages as one JSON
/// document per line. Inbound data may arrive in arbitrary chunks that cut a
/// message mid-line; [MessageBuffer] retains the partial tail and yields only
/// complete lines, so it can sit directly in front of [parse_message].
pub(all) struct MessageBuffer {
  mut pending : String
}

///|
/// Create an empty message buffer.
pub fn MessageBuffer::new() -> MessageBuffer {
  { pending: "" }
}

///|
/// Strip a trailing carriage return left behind by CRLF line endings.
fn clean_line(line : StringView) -> String {
  line.to_owned().trim_end(chars="\r").to_owned()
}

///|
/// Append a chunk of inbound text and return every complete line it yields
/// (without the terminating newline). Any partial trailing line is retained
/// internally and completed by a later call.
pub fn MessageBuffer::push(
  self : MessageBuffer,
  chunk : String,
) -> Array[String] {
  self.pending = self.pending + chunk
  let lines : Array[String] = []
  let mut done = false
  while !done {
    match self.pending.split_once("\n") {
      Some((line, rest)) => {
        lines.push(clean_line(line))
        self.pending = rest.to_owned()
      }
      None => done = true
    }
  }
  lines
}
