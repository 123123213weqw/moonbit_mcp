# Architecture

This document describes the runtime boundaries, ownership model, lifecycle, and
extension points of `moonbit_mcp`. It is intended for maintainers and reviewers
who need to reason about behavior beyond the public API snapshot.

## Design goals

1. Keep protocol values strongly typed while retaining JSON extension fields at
   method boundaries.
2. Separate message parsing, request dispatch, transport, and application code.
3. Make the same core package work on wasm, wasm-gc, JavaScript, and native.
4. Keep I/O outside the protocol core so embedders choose their own runtime.
5. Make every wire-visible behavior testable without a network dependency.
6. Fail malformed peer input as JSON-RPC errors rather than crashing.
7. Keep generated public interfaces in version control for review.

## Layer map

```text
application callbacks
        │
        ▼
McpServer builder ───────────── Client request builders
        │                                │
        ▼                                ▼
Server dispatcher                 Client correlator
        │                                │
        └──────── JSON-RPC model ────────┘
                         │
                         ▼
             newline message framing
                         │
                         ▼
                 Transport trait
```

### Protocol model

`jsonrpc.mbt` owns request identifiers, requests, notifications, responses, and
strict parsing. It enforces the invariants shared by every MCP operation:

- `jsonrpc` is present and exactly `"2.0"`;
- request identifiers are integers or strings and are never null;
- a method is a string;
- parameters, when present, are an object or array;
- responses contain an identifier and exactly one of `result` or `error`;
- error codes are integers and error messages are strings.

Parsing returns `Result[RpcMessage, McpError]`. It does not throw for peer input.
Serialization is centralized in `message_to_string`, so servers and clients emit
the same canonical shape.

### MCP data types

The model is split by protocol feature rather than transport concern:

| File | Responsibility |
|---|---|
| `content.mbt` | text, image, audio, links, embedded resources |
| `tools.mbt` | tool metadata, annotations, call results |
| `resources.mbt` | resources, URI templates, read results |
| `prompts.mbt` | prompt definitions, arguments, rendered messages |
| `logging.mbt` | syslog-compatible levels and log messages |
| `capabilities.mbt` | initialize-time server capability advertisement |
| `schema.mbt` | the JSON Schema subset used by tool inputs |
| `pagination.mbt` | item pages and continuation cursors |
| `protocol.mbt` | method names and the supported MCP revision |

These files contain no I/O. Their `to_json` methods are deterministic with
respect to value content, although callers must not depend on object-key order.

### Server dispatcher

`Server` is the low-level request router. It owns:

- immutable implementation metadata;
- mutable capability flags;
- a method-to-handler map;
- whether the initialized notification was observed.

`Server::process_message` parses one complete JSON-RPC message. Requests are
answered, notifications produce no response, and inbound responses are ignored.
The built-in `initialize` and `ping` operations are handled before the custom
handler map.

A `MethodHandler` receives raw JSON parameters plus a snapshot of
`ServerContext`. The handler returns `Result[Json, McpError]`. The dispatcher
preserves the request identifier and converts failures to JSON-RPC error objects.

`Server` intentionally does not enforce application authorization, quotas, URI
access policy, or tool argument schemas. Those policies belong at registration
callbacks or at a transport boundary.

### High-level server

`McpServer` provides ergonomic registration for the three server-owned MCP
features:

- `tool` and `tool_desc` register tool metadata and callbacks;
- `resource` registers concrete URI metadata and a read callback;
- `prompt` registers prompt metadata and a rendering callback.

Construction enables tools, resources, and prompts capabilities and installs the
six list/call/read/get handlers. Callback arrays and maps are captured by the
handlers, allowing registrations made after construction to remain visible.

The high-level builder is deliberately small. Applications that need custom
methods, subscription stores, authentication contexts, or experimental protocol
features can call `inner()` and register a `MethodHandler` directly.

### Client core

`Client` is a transport-independent state machine with four responsibilities:

1. allocate monotonically increasing integer request identifiers;
2. build MCP requests and notifications;
3. correlate out-of-order responses by identifier;
4. record the negotiated protocol version and server implementation.

Every `build_*` request returns `(RequestId, String)`. The identifier must be kept
until the response is fed through `handle_message` and retrieved with
`take_result`. Retrieval removes the response, preventing accidental reuse.

The client records server notifications in arrival order. Server-initiated
requests such as sampling are parsed but are not automatically answered. An
application that enables those capabilities should place its own router above
the client core.

### Connections and framing

`MessageBuffer` converts arbitrary string chunks to complete newline-delimited
messages. It handles LF and CRLF, several messages in one chunk, and messages
split across chunks. An unterminated suffix remains pending.

`ServerConnection[T]` combines a `Server`, `MessageBuffer`, and `Transport`.
Every framed request is dispatched and every response is sent through the
transport.

`ClientConnection[T]` mirrors that design. It sends built requests through the
transport, frames inbound chunks, and gives complete responses to the client
correlator.

Neither connection assumes operating-system sockets. A browser WebSocket,
worker channel, HTTP response body, native stdio loop, or test double can adapt
to the same surface.

### Transport abstraction

`Transport` currently requires a single `send(String)` operation. Two portable
implementations ship in the core package:

- `BufferedTransport` records outbound messages for assertions and batch use;
- `InMemoryTransport::pair` creates linked endpoints for synchronous loopback.

Close operations are explicit on concrete transports. Sending after close is a
no-op for the built-in implementations. Production adapters should document
whether send is synchronous, buffered, fallible, ordered, and safe to re-enter.

## Lifecycle

A normal session follows this sequence:

```text
client                                      server
  │ initialize -------------------------------->│
  │<---------------- initialize result          │
  │ notifications/initialized ----------------->│
  │                                             │
  │ tools/list -------------------------------->│
  │<---------------- tools result               │
  │ tools/call -------------------------------->│
  │<---------------- call result                │
```

The client calls `complete_initialize` or `take_initialize` before marking the
session initialized. The server marks its session initialized only after the
notification. The current dispatcher remains permissive and does not reject
feature calls made before initialization; a strict host can enforce ordering at
the transport boundary.

## Mutability and ownership

MoonBit values in the SDK use mutation only where it models evolving state:

- request identifier counters;
- pending response maps;
- notification queues;
- handler registries;
- registered feature arrays and callback maps;
- connection framing buffers;
- fluent builder metadata.

Wire values passed across API boundaries are ordinary MoonBit values. Callback
registries do not use global state. Multiple servers and clients can coexist in
one process without identifier or handler collisions.

## Error boundaries

Errors are divided into these categories:

| Variant | Boundary | JSON-RPC mapping |
|---|---|---:|
| `ParseError` | invalid wire JSON or shape | `-32700` |
| `ProtocolError` | invalid lifecycle/result semantics | `-32600` |
| `UnknownMethod` | unavailable method | `-32601` |
| `UnknownTarget` | unknown tool/resource/prompt | `-32602` |
| `InvalidArguments` | invalid method parameters | `-32602` |
| `TransportError` | adapter failure | `-32603` |
| `RpcError` | error returned by a peer | preserved |

The server uses request id `0` when it cannot recover an identifier from a
malformed message. This is an SDK representation constraint: `RequestId` excludes
null. Applications comparing strict JSON-RPC parse-error fixtures should account
for that documented behavior.

## Extension strategy

Add protocol behavior at the narrowest layer that owns its invariant:

- add a method name to `protocol.mbt`;
- add reusable wire values in a feature-specific file;
- add client request builders only when request construction is stable;
- add server registration helpers only for common callback patterns;
- keep runtime-specific I/O under `cmd/` or in downstream packages;
- add black-box fixtures before claiming interoperability.

An experimental method can be implemented without changing the core model:

```moonbit
let server = Server::new("experimental", "0.1")
ignore(server.handle_method("x/status", fn(_params, context) {
  let result : Map[String, Json] = Map([])
  result["initialized"] = Json::boolean(context.initialized)
  Ok(Json::object(result))
}))
```

## Repository boundaries

Published-package exclusions in `moon.mod` keep CI configuration, documentation,
scripts, fixtures, examples, and white-box tests out of the runtime artifact.
The committed `pkg.generated.mbti` is the review contract for the root package.
Executable packages keep their own interface snapshots.

The repository is verification-first: a feature is complete only when its model,
wire behavior, multi-target tests, documentation, and public interface agree.
