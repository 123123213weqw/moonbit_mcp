# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-08-24

### Added
- High-level concrete resource registration/read callbacks and prompt
  registration/render callbacks on `McpServer`.
- Client and connection builders for resource list/read/subscribe, prompt
  list/get, logging level, and generic notifications.
- Fluent resource, resource-template, prompt, prompt-message, and prompt-result
  constructors.
- 15-case black-box subprocess conformance corpus and reusable standard-library
  Python runner with JSON evidence reports.
- Tracked-file engineering audit with reviewable thresholds based on the
  `moon_proto` engineering standard.
- Architecture, support, transport, testing, security, development, release,
  reviewer, contribution, conduct, and reporting documentation.
- Issue/PR templates and CI-uploaded engineering/conformance evidence.
- 37 unit tests for the Python verification tools.

### Changed
- JSON-RPC decoding is strict about protocol version, identifier type, parameter
  shape, response result/error exclusivity, integer error codes, and error data.
- `McpServer` now advertises tools, resources, and prompts capabilities.
- CI runs the complete release gate with full Git history and pinned stable
  GitHub action majors.
- Package version raised to `0.7.0`.

### Fixed
- Missing `tools/call` names or arguments now return typed invalid-parameter
  errors instead of aborting on direct map indexing.
- The reference echo callback handles absent `message` safely.
- JSON-RPC error response `data` is retained during decoding.

### Verification
- 161 MoonBit tests pass on wasm, wasm-gc, JavaScript, and native.
- 37 Python verification-tool tests pass.
- 15/15 black-box MCP cases pass against `cmd/mcp-echo`.
- The repository reaches the 95-commit reference-history floor without filler
  commits; each uplift commit is a focused feature, fix, test, documentation, or
  automation change.

## [0.6.0]

### Added
- `ClientConnection[T : Transport]`: the client-side mirror of
  `ServerConnection`. Builds-and-sends requests through a transport
  (`send_initialize` / `send_initialized` / `send_ping` / `send_tools_list` /
  `send_tools_call` / `send_request` / `send_raw`), frames inbound chunks with
  a `MessageBuffer`, and feeds each complete message to `Client::handle_message`
  for response correlation. `take_initialize` completes the initialize
  handshake from the correlated response.
- `Client::complete_initialize_result`: complete the initialize handshake from
  an already-extracted `result` JSON value.
- `cmd/mcp-loopback`: a runnable end-to-end demo — a `ClientConnection` and a
  `ServerConnection` wired back-to-back through linked in-memory transports,
  running the full initialize → tools/list → tools/call session in one
  process. Run it with `moon run cmd/mcp-loopback --target native`.

## [0.5.0]

### Added
- `cmd/mcp-echo`: a runnable stdio MCP server binary. Reads newline-delimited
  JSON-RPC from stdin (via a native `getchar` FFI loop), serves a single `echo`
  tool built on `McpServer`, and writes responses to stdout. Run it with
  `moon run cmd/mcp-echo --target native`.

## [0.4.0]

### Added
- `ServerConnection[T : Transport]`: drives a `Server` (or a `McpServer` via
  `inner()`) from arbitrary inbound chunks — framing them with a `MessageBuffer`,
  dispatching each complete message, and routing responses back through the
  transport. Adds `receive`, `receive_line`, and `has_pending`.

## [0.3.0]

### Added
- `MessageBuffer` framing: reassembles a chunked byte stream into complete
  newline-delimited JSON-RPC messages, with CRLF tolerance, a `feed` helper that
  forwards framed lines to a `MessageHandler`, and `has_pending` state.

## [0.2.0]

### Added
- Low-level `Client`: request-id allocation, request builders (`initialize`,
  `ping`, `tools/list`, `tools/call`), response correlation via `take_result`,
  server notification capture, and the initialize handshake.

### Changed
- `RequestId` now derives `Hash` so it can key the client's pending-response map.

## [0.1.0]

### Added
- Initial MCP SDK scaffold: protocol types, server, client, transport.
