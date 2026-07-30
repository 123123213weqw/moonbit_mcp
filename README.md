# MoonBit MCP SDK

[![CI](https://github.com/123123213weqw/moonbit_mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/123123213weqw/moonbit_mcp/actions/workflows/ci.yml)
![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20260713-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**A MoonBit SDK for the [Model Context Protocol](https://modelcontextprotocol.io/) (MCP).**

Build MCP servers and clients in MoonBit — connect to Claude, Cursor, and any MCP-compatible AI agent.

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
      let msg = @mcp.ContentBlock::as_text(
        @mcp.ContentBlock::TextContent("echo: " + args.stringify(), None)
      ).or_else(fn() { "no args" })
      @mcp.CallToolResult::text(msg)
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

  // 1. Open the session: send the initialize request, feed the response back.
  let (_init_id, init_req) = client.build_initialize()
  // transport.send(init_req)
  // ignore(client.complete_initialize(response_line))

  // 2. List tools, correlating the response by request id.
  let (list_id, list_req) = client.build_tools_list()
  // transport.send(list_req)
  // ignore(client.handle_message(response_line))
  // let tools = client.take_result(list_id)
  ignore((init_req, list_id))
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

## What This Provides

| Layer | Modules |
|-------|---------|
| **Protocol** | JSON-RPC 2.0 parsing/encoding, MCP message types (Request/Response/Notification) |
| **Types** | ContentBlock (text/image/audio/resource), Tool, Resource, Prompt, LogMessage |
| **Server** | Low-level `Server` (handler registry + dispatch) + high-level `McpServer` builder |
| **Client** | Low-level `Client` (request-id allocation, request builders, response correlation, initialize handshake) |
| **Schema** | JSON Schema builder for tool input/output schemas |
| **Transport** | `trait Transport` abstraction + `InMemoryTransport` (tests) + `BufferedTransport` |
| **Framing** | `MessageBuffer` — reassembles a chunked byte stream into newline-delimited JSON-RPC messages (stdio / streamable-HTTP) |
| **Connection** | `ServerConnection` — drives a `Server` from any byte stream: frames inbound chunks, dispatches them, routes responses through a `Transport` |

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

## Development

```bash
moon fmt --check          # format check
moon check --deny-warn    # type check (warnings as errors)
moon test --deny-warn     # run tests
moon test --target all    # wasm / wasm-gc / js / native
moon info                 # regenerate public interface snapshot
```

## Test Results

- `moon test --target all`: **43/43 passed** on all 4 targets
- `moon check --deny-warn`: 0 warnings, 0 errors

## License

MIT
