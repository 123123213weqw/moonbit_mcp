# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
