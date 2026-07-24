# MoonBit MCP SDK — AI Agent Collaboration Guide

## Project Goal
A MoonBit SDK for the Model Context Protocol (MCP), targeting protocol version `2025-06-18`.

## Development Commands
```bash
moon fmt --check          # format check (every top-level def needs a `///|` doc comment)
moon check --deny-warn    # type check, warnings as errors
moon test --deny-warn     # run tests, warnings as errors
moon test --target all    # wasm-gc / wasm / js / native
moon info                 # regenerate pkg.generated.mbti
moon build                # build
```

## Conventions (inherited from moon_proto)
- Every top-level definition must have a `///|` doc comment (even if empty).
- All public enums/structs use `derive(Debug, Eq)` and `pub(all)` visibility.
- Internal helpers use `priv`.
- Error handling: define `enum XxxResult { XxxOk(..); XxxErr(McpError) }` — no exceptions for control flow.
- Tests: white-box `*_wbtest.mbt` files with `assert_eq` / `assert_true` / `fail`.
- Source files are flat in the root package (no subdirectories for core `.mbt` files).

## Relationship to moon_proto
- moon_proto: static `.proto` schema validation + protobuf wire codec.
- moonbit_mcp: dynamic AI Agent tool protocol (JSON-RPC over stdio/HTTP).
- Zero overlap. The two can coexist: parse `.proto` with moon_proto, expose as MCP resource.
