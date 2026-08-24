# MoonBit MCP SDK

[![CI](https://github.com/123123213weqw/moonbit_mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/123123213weqw/moonbit_mcp/actions/workflows/ci.yml)
![Package](https://img.shields.io/badge/package-v0.7.0-blue)
![Protocol](https://img.shields.io/badge/MCP-2025--06--18-purple)
![License](https://img.shields.io/badge/license-MIT-green)

**A MoonBit SDK for the [Model Context Protocol](https://modelcontextprotocol.io/) (MCP).**

Build MCP servers and clients in MoonBit with strict JSON-RPC parsing, typed
content, high-level tools/resources/prompts registries, transport-neutral
connections, and verification across wasm, wasm-gc, JavaScript, and native.

> **Scope:** the SDK targets MCP revision `2025-06-18`. See the
> [support matrix](docs/PROTOCOL_SUPPORT.md) for Complete, Core, Constant, and
> Planned behavior rather than assuming full coverage from an exported type.

## 30-Second Quick Start

### Install

```bash
moon add 123123213weqw/moonbit_mcp
```

### Minimal Echo Server

```moonbit
import {
  "123123213weqw/moonbit_mcp" @mcp,
}

///|
fn main {
  let server = @mcp.McpServer::new("echo-server", "1.0.0")
  server.tool(
    "echo",
    @mcp.JsonSchema::object() |> @mcp.JsonSchema::string("message"),
    fn(args) {
      @mcp.CallToolResult::text("echo: " + args.stringify())
    },
  )
  // In a real server, you'd drive server.process_message(raw) from a transport.
}
```

### Minimal Client

```moonbit
import {
  "123123213weqw/moonbit_mcp" @mcp,
}

///|
fn main {
  let client = @mcp.Client::new("my-client", "1.0.0")
  // Pass any @mcp.Transport that reaches your server (stdio / HTTP / in-memory).
  let (transport, _peer) = @mcp.InMemoryTransport::pair()
  let conn = @mcp.ClientConnection::new(client, transport)

  // 1. Open the session: send initialize, feed the response bytes back in.
  let init_id = conn.send_initialize()
  // conn.receive(server_bytes)            // feed inbound server bytes
  // let info = conn.take_initialize(init_id)
  // conn.send_initialized()

  // 2. List tools, correlating the response by request id.
  let list_id = conn.send_tools_list()
  // conn.receive(server_bytes)
  // let tools = client.take_result(list_id)
  ignore((init_id, list_id))
}
```

### Run the Echo Server

The repo ships a ready-to-run stdio server in `cmd/mcp-echo`. Build it for the
native target and talk to it over stdin/stdout:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"you","version":"0.0.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo","arguments":{"message":"hi"}}}' \
  | moon run cmd/mcp-echo --target native
```

Each input line is a JSON-RPC message; each response is printed on its own line.

### Run the Loopback Demo

`cmd/mcp-loopback` runs a full MCP session in one process: a `ClientConnection`
and a `ServerConnection` wired back-to-back through linked in-memory
transports — initialize handshake, `tools/list`, and an `echo` tool call:

```bash
moon run cmd/mcp-loopback --target native
```

## What This Provides

| Layer | Modules |
|-------|---------|
| **Protocol** | JSON-RPC 2.0 parsing/encoding, MCP message types (Request/Response/Notification) |
| **Types** | ContentBlock (text/image/audio/resource), Tool, Resource, Prompt, LogMessage |
| **Server** | Low-level dispatch plus high-level tool, concrete-resource, and prompt registries |
| **Client** | Request-id allocation, response correlation, initialize, tools, resources, prompts, and logging builders |
| **Schema** | JSON Schema builder for tool input/output schemas |
| **Transport** | `trait Transport` abstraction + `InMemoryTransport` (tests) + `BufferedTransport` |
| **Framing** | `MessageBuffer` — reassembles a chunked byte stream into newline-delimited JSON-RPC messages (stdio / streamable-HTTP) |
| **Connection** | `ServerConnection` — drives a `Server` from any byte stream: frames inbound chunks, dispatches them, routes responses through a `Transport` |
| | `ClientConnection` — drives a `Client` over any byte stream: builds-and-sends requests through a `Transport`, frames inbound chunks, correlates responses |

## Architecture

```
┌─────────────────────────────────┐
│  McpServer (high-level builder) │
│  .tool() / .resource() / ...    │
└──────────────┬──────────────────┘
               │ registers handlers
┌──────────────▼──────────────────┐
│  Server (low-level dispatcher)  │
│  initialize / tools/list / call │
│  + capability negotiation       │
└──────────────┬──────────────────┘
               │ uses
┌──────────────▼──────────────────┐
│  JSON-RPC 2.0 parse_message()   │
│  + message_to_string()          │
└──────────────┬──────────────────┘
               │ drives any
┌──────────────▼──────────────────┐
│  trait Transport                │
│  InMemoryTransport | Buffered   │
└─────────────────────────────────┘
```

## Relationship to moon_proto

- **[moon_proto](https://github.com/123123213weqw/moon_proto)**: static `.proto` schema validation + protobuf wire codec
- **moonbit_mcp**: dynamic AI Agent tool protocol (JSON-RPC over stdio/HTTP)

Zero overlap. The two can coexist: parse `.proto` with moon_proto, expose as MCP resources with moonbit_mcp.

## Verification

Run the same release gate as CI:

```bash
./scripts/release_gate.sh
```

It verifies formatting, generated interfaces, warnings-as-errors, build, **161
MoonBit tests on every target**, 37 Python verification-tool tests, 15 black-box
MCP cases, and the tracked-file engineering evidence floor.

Focused commands:

```bash
moon test --deny-warn
moon test --target all
python3 scripts/mcp_conformance.py run -- \
  moon run cmd/mcp-echo --target native
python3 scripts/project_audit.py --format markdown
```

## Engineering Evidence

The v0.7.0 uplift brings the history to **95 focused commits**, expands MoonBit
source/test/example code from 2,643 to more than 4,000 nonblank lines, increases
the MoonBit suite from 52 to 161 executed tests, and adds executable conformance,
repository audit tooling, CI evidence artifacts, governance templates, and a
review-oriented documentation set. Counts come from tracked files only; ignored
build output cannot inflate them.

See [Engineering Report](docs/ENGINEERING_REPORT.md) for baseline/delta details.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Protocol support matrix](docs/PROTOCOL_SUPPORT.md)
- [Transport integration](docs/TRANSPORTS.md)
- [Testing and verification](docs/TESTING.md)
- [Security model](docs/SECURITY_MODEL.md)
- [Development guide](docs/DEVELOPMENT.md)
- [Reviewer playbook](docs/REVIEWER_PLAYBOOK.md)
- [Release process](docs/RELEASE.md)
- [Contributing](CONTRIBUTING.md) and [security reporting](SECURITY.md)

## License

MIT
