# Transport Integration Guide

The SDK deliberately separates MCP messages from I/O. This guide explains how
to adapt stdio, HTTP streams, WebSockets, worker channels, and test harnesses to
the `Transport`, `MessageBuffer`, `ServerConnection`, and `ClientConnection`
surfaces.

## Contract

A transport used for outbound SDK traffic implements:

```moonbit
pub trait Transport {
  send(Self, String) -> Unit
}
```

The string is one complete JSON-RPC message without a required trailing newline.
The adapter decides whether to add framing bytes. Delivery order must match call
order. If the underlying channel can fail, expose that failure in the adapter API
before or after calling the connection; the minimal trait itself is infallible.

Document these properties for every production adapter:

- whether `send` blocks;
- whether it buffers;
- whether callbacks may re-enter the adapter;
- maximum message size;
- text encoding;
- close semantics;
- error and retry semantics;
- ordering across concurrent producers.

## Newline streams

Native stdio and many subprocess integrations carry one JSON value per line.
Use `MessageBuffer` rather than assuming a read returns one message. Operating
systems can split a line anywhere or combine several lines in one read.

```moonbit
let buffer = MessageBuffer::new()
buffer.feed(chunk, fn(line) {
  match server.process_message(line) {
    Some(response) => write_line(response)
    None => ()
  }
})
```

The buffer:

- emits complete records on LF;
- removes a preceding CR for CRLF input;
- retains an unterminated tail;
- accepts an empty chunk;
- can emit several records from one chunk.

A blank record is emitted for consecutive newlines. A connection will attempt to
parse it and skip the malformed line in chunk mode. Strict applications can call
`receive_line` themselves and surface its parse error.

### Native stdio reference

`cmd/mcp-echo` demonstrates byte-by-byte native input with the core framing
behavior. Run it with:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"ping"}' \
  | moon run cmd/mcp-echo --target native
```

Keep diagnostics on stderr. Stdout belongs exclusively to protocol messages; a
banner or debug line corrupts the stream.

Some runtimes buffer stdout when the peer keeps stdin open. Flush after every
message in production adapters. The black-box conformance runner isolates cases
and closes stdin so it also works with buffered reference executables.

## Message transports

WebSockets and worker channels already preserve message boundaries. Call
`ServerConnection::receive_line` or `ClientConnection::receive_line` for each
text message. Do not append newlines unless the adapter intentionally exposes a
stream abstraction.

Reject binary WebSocket frames unless the adapter defines an explicit UTF-8
conversion. MCP JSON-RPC messages are text. Resource blob fields remain base64
strings inside JSON.

## Streamable HTTP

An HTTP adapter owns more policy than the core SDK:

1. request method and content-type validation;
2. authentication and authorization;
3. origin validation where browser traffic is possible;
4. session identifier generation and lookup;
5. request-body size and timeout limits;
6. SSE or chunked response framing;
7. reconnect and last-event behavior;
8. mapping disconnects to cancellation.

Feed each decoded JSON message to the server dispatcher. Never pass HTTP header
values into method callbacks without validation. A transport session should own
one logical `Server` state when initialized state or subscriptions matter.

The SDK's newline buffer can help only after the HTTP adapter has selected and
decoded a text body. It does not implement the Streamable HTTP specification by
itself.

## In-memory loopback

`InMemoryTransport::pair` creates linked endpoints. A handler registered on one
endpoint receives values sent through its peer synchronously.

```moonbit
let (to_server, to_client) = InMemoryTransport::pair()
let server_connection = ServerConnection::new(server, to_client)
let client_connection = ClientConnection::new(client, to_server)

to_client.on_message(fn(message) {
  server_connection.receive_line(message)
})
to_server.on_message(fn(message) {
  ignore(client_connection.receive_line(message))
})
```

Because delivery is synchronous, a complete request/response exchange can finish
before `send_*` returns. This is excellent for deterministic tests. It does not
model latency, backpressure, partial writes, disconnect races, or concurrency.
Use an adapter-specific integration suite for those properties.

## Buffered transport

`BufferedTransport` is a recording sink:

```moonbit
let output = BufferedTransport::new()
let connection = ClientConnection::new(client, output)
let id = connection.send_ping()
let messages = output.messages()
```

`messages()` returns the accumulated array. Closing the transport makes later
sends no-ops. Use it for request-shape tests, golden generation, and embedding
scenarios that hand a batch to another runtime.

## Adapter blueprint

A production adapter generally has these components:

```text
runtime reader
  -> size limiter
  -> UTF-8 decoder
  -> framing
  -> receive_line
  -> server/client core
  -> Transport.send
  -> runtime writer + flush
```

Place observability around complete messages, not arbitrary chunks. Redact tool
arguments, prompt values, resource contents, authorization headers, and embedded
base64 unless an explicit diagnostic mode permits them.

### Backpressure

The minimal transport trait does not express readiness. An adapter with bounded
queues should expose its own async or polling layer and call the SDK only when it
can accept a complete outbound message. Never silently discard responses.

Possible policies include:

- close the session on queue overflow;
- reject a request before dispatch when capacity is unavailable;
- bound concurrent callbacks;
- apply per-method deadlines;
- reserve response capacity before executing a tool.

### Reentrancy

The in-memory transport can invoke callbacks during `send`. Production adapters
should decide whether this is allowed. If not, enqueue the message and drain it
after the current call. Avoid holding adapter locks while invoking application
tool callbacks.

### Close behavior

Define whether close:

- rejects new sends;
- drains queued messages;
- cancels running operations;
- clears subscriptions;
- retains session state for reconnect;
- emits a final protocol or transport error.

Built-in close methods are local and idempotent. They do not send protocol
notifications.

## Limits

Apply limits before allocating unbounded buffers:

| Limit | Suggested location |
|---|---|
| maximum line/message bytes | framing adapter |
| maximum JSON nesting | JSON parser boundary |
| maximum pending requests | client/session wrapper |
| maximum tool argument bytes | method policy |
| maximum resource output bytes | resource callback wrapper |
| maximum base64 payload | content policy |
| request deadline | runtime scheduler |
| idle session lifetime | session manager |

Exact values depend on the host. Record them in operator documentation and test
both boundary and over-limit cases.

## Testing an adapter

At minimum, verify:

1. a request split at every possible byte boundary;
2. several messages in one read;
3. CRLF and LF;
4. Unicode split across runtime byte reads before UTF-8 decoding;
5. empty and oversized input;
6. malformed JSON followed by a valid request;
7. notification produces no response;
8. response identifiers preserve string and integer types;
9. close during a request;
10. writer failure and partial write;
11. stdout/protocol channel contains no diagnostics;
12. authentication context does not leak across sessions.

Run the repository black-box corpus against the adapter executable when it uses
newline-delimited stdin/stdout:

```bash
python3 scripts/mcp_conformance.py run -- ./your-server
```

## Choosing the right API

| Input form | Recommended API |
|---|---|
| arbitrary stream chunks | `connection.receive` |
| one complete JSON message | `connection.receive_line` |
| direct unit test | `server.process_message` |
| client request construction only | `client.build_*` |
| custom runtime batching | `BufferedTransport` |
| deterministic end-to-end test | `InMemoryTransport::pair` |

Keep the protocol core unaware of file descriptors, event loops, HTTP libraries,
and platform threads. That boundary is what keeps the root package portable
across all four tested MoonBit targets.
