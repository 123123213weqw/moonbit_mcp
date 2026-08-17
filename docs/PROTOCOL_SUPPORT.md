# Protocol Support Matrix

`moonbit_mcp` targets MCP revision `2025-06-18`. This matrix distinguishes
implemented behavior from named constants and planned work. It is intentionally
conservative: an exported type alone is not counted as end-to-end support.

## Legend

- **Complete**: public model/builders, server or client behavior, and tests exist.
- **Core**: wire model or method builder exists; application routing is required.
- **Constant**: method name exists so custom handlers can use it.
- **Planned**: no stable public abstraction is claimed.

## Base protocol

| Capability | Status | Evidence |
|---|---|---|
| JSON-RPC requests | Complete | strict parser, encoder, conformance tests |
| JSON-RPC notifications | Complete | parser, encoder, no-response dispatch |
| JSON-RPC success responses | Complete | correlation and null-result coverage |
| JSON-RPC error responses | Complete | optional data retained, code preserved |
| Integer identifiers | Complete | positive, zero, and negative test cases |
| String identifiers | Complete | empty, Unicode-safe JSON string handling |
| Batch JSON-RPC | Planned | MCP transports use individual messages |
| Cancellation notification | Constant | applications track their own operations |
| Progress notification | Constant | token model not yet specialized |
| Ping | Complete | server dispatch and client builder |

## Lifecycle

| Operation | Client | Server | Notes |
|---|---|---|---|
| `initialize` | Complete | Complete | negotiates revision and implementation |
| `notifications/initialized` | Complete | Complete | client builder; server state transition |
| capability advertisement | Core | Complete | server flags are typed |
| strict pre-init rejection | Planned | Planned | permissive for embedding compatibility |
| graceful shutdown | Application | Application | owned by transport/runtime |

## Tools

| Operation | Status | Notes |
|---|---|---|
| `tools/list` | Complete | high-level registry and client builder |
| `tools/call` | Complete | object arguments, callback result/error |
| `notifications/tools/list_changed` | Constant | capability is advertised |
| input schema construction | Complete subset | object properties and primitive types |
| output schema metadata | Core | represented by `Tool` |
| annotations | Core | typed hints; applications choose policy |
| structured content | Core | raw JSON extension possible |
| schema enforcement | Application | validate before invoking sensitive tools |

The schema builder intentionally implements a practical subset, not all JSON
Schema drafts. Consumers needing unions, references, bounds, patterns, arrays of
typed items, or `additionalProperties` can construct JSON directly in a custom
`Tool` integration until the typed builder expands.

## Resources

| Operation | Status | Notes |
|---|---|---|
| `resources/list` | Complete | concrete resources registry |
| `resources/read` | Complete | URI-keyed reader callbacks |
| `resources/templates/list` | Constant/Core | template type and encoder exist |
| `resources/subscribe` | Client Core | request builder exists |
| `notifications/resources/updated` | Constant | application subscription store required |
| `notifications/resources/list_changed` | Constant | capability is advertised |
| text contents | Complete | URI, optional MIME type, text |
| binary contents | Core | caller supplies base64 data |
| RFC 6570 expansion | Planned | templates are metadata only |
| pagination | Core | cursor type exists; registries return one page |

Resource callbacks should treat URIs as untrusted input. The built-in registry
matches exact registered URIs and never reads the filesystem itself.

## Prompts

| Operation | Status | Notes |
|---|---|---|
| `prompts/list` | Complete | typed definitions and registry |
| `prompts/get` | Complete | JSON argument callback |
| `notifications/prompts/list_changed` | Constant | capability is advertised |
| user text messages | Complete | convenience constructor |
| assistant text messages | Complete | convenience constructor |
| multimodal messages | Core | use any `ContentBlock` directly |
| required argument enforcement | Application | metadata is exposed to clients |
| pagination | Core | method accepts custom cursor builders |

## Logging

| Operation | Status | Notes |
|---|---|---|
| `logging/setLevel` | Client Core | typed level request builder |
| `notifications/message` | Core | typed `LogMessage` encoding |
| server log filtering | Application | runtime policy is host-specific |
| syslog-compatible levels | Complete | eight protocol spellings tested |

## Client-originated features

MCP features where the server calls back into the client need an application
router above `Client::handle_message` in this release.

| Feature | Status | Integration path |
|---|---|---|
| roots/list | Planned | register a server-request handler in host |
| roots list changed | Planned | send a client notification |
| sampling/createMessage | Planned | host approval and model adapter required |
| elicitation/create | Planned | host UI and validation required |

The low-level JSON-RPC model can represent these server-initiated requests. The
current `Client` acknowledges parsing but does not synthesize responses. This is
a deliberate safety boundary: sampling and elicitation require host policy and
user-interaction decisions that a protocol library must not guess.

## Content model

| Content kind | Encode | Decode helper | Notes |
|---|---|---|---|
| text | Complete | `as_text` | annotations represented |
| image | Complete | application | base64 plus MIME type |
| audio | Complete | application | base64 plus MIME type |
| resource link | Complete | application | URI and display metadata |
| embedded text resource | Complete | application | used by prompts/tools |
| embedded blob resource | Complete | application | base64 remains caller-owned |

## Transports

| Transport | Framing | Implementation |
|---|---|---|
| in-memory | message | built in |
| buffered test sink | message | built in |
| native stdio | newline | `cmd/mcp-echo` reference executable |
| Streamable HTTP | newline helper only | downstream adapter required |
| WebSocket | message | downstream adapter required |
| browser worker | message | downstream adapter required |

The SDK does not claim HTTP authorization, origin validation, session header, or
reconnection behavior. Those are adapter responsibilities and must be tested in
the adapter repository.

## Target matrix

The portable root package is checked and tested on:

- wasm;
- wasm-gc;
- JavaScript;
- native.

Native-only stdio FFI is guarded with `#cfg(target="native")`. Protocol models,
registries, loopback connections, and tests remain target-independent.

## Compatibility policy

1. The `latest_protocol_version` constant is the revision emitted during
   initialize.
2. A revision change requires fixture updates, support-matrix review, and a
   changelog entry.
3. Optional fields may be added compatibly; public type changes still update the
   committed `.mbti` snapshot.
4. Unknown JSON object members are tolerated where the typed model does not need
   them.
5. Unsupported operations are not advertised as complete merely because their
   method constant exists.
6. Runtime adapters publish their own compatibility claims.

## How to verify a claim

Run the complete gate:

```bash
./scripts/release_gate.sh
```

For a black-box server check only:

```bash
python3 scripts/mcp_conformance.py run -- \
  moon run cmd/mcp-echo --target native
```

For the evidence summary:

```bash
python3 scripts/project_audit.py --format markdown
```
