# Engineering Uplift Report

This report records the `moonbit_mcp` uplift against the engineering practices
observed in `moon_proto`. The comparison is not a claim that MCP and Protocol
Buffers need identical implementation size; it establishes comparable evidence:
focused history, substantive code, enforceable conventions, deep documentation,
and layered tests.

## Method

The before baseline is repository commit `65600c6` (the previous `main` head).
The after baseline is release `0.7.0` at 95 commits.

`scripts/project_audit.py` counts only paths returned by `git ls-files`. It excludes
ignored `_build`, `.git`, editor cache, and local environment files by design.
Nonblank lines include code comments because maintained API/security comments are
part of the reviewed source. Generated `.mbti` files are reported separately and
do not contribute to the MoonBit code floor.

## Result summary

| Evidence | Before | v0.7.0 | Change |
|---|---:|---:|---:|
| Git commits | 82 | 95 | +13 focused commits |
| Tracked files | 42 | 70+ | repository evidence expanded |
| MoonBit nonblank source/test/example lines | 2,643 | 4,086 | +1,443 (+55%) |
| Executed MoonBit tests | 52 | 161 | +109 (3.1×) |
| Python verification-tool tests | 0 | 37 | new |
| Black-box MCP cases | 0 | 15 | new |
| Python verification code | 0 | 890 nonblank lines | new |
| Documentation files | 3 | 16+ | 5×+ |
| Documentation nonblank lines | 194 | 1,700+ | 8×+ |
| Supported MoonBit test targets | 4 | 4 | retained |

The final authoritative values are printed by:

```bash
python3 scripts/project_audit.py --format markdown
```

## Commit-quality comparison

The requested history floor is reached with exactly 13 additional logical
commits rather than empty or metadata-only padding:

1. complete resource and prompt value builders;
2. add high-level server resource/prompt registries;
3. add client resource/prompt/logging request surfaces;
4. verify feature flows;
5. harden JSON-RPC and add edge-case tests;
6. add black-box conformance and fix discovered aborts;
7. enforce measurable engineering floors;
8. expand model, transport, schema, and error tests;
9. document architecture, support, and transports;
10. document testing, security, release, and review;
11. add contribution and issue governance;
12. publish full CI verification evidence;
13. finalize verification-tool tests, package docs, interfaces, and release.

This sequence makes the evolution reviewable and bisectable. No empty commits are
used.

## Code and API uplift

### Server

The high-level builder previously registered only tools. It now supports concrete
resources and prompts with list/read/get handlers, typed callbacks, capability
advertisement, safe missing-parameter handling, and unknown-target errors.

### Client

The client and connection now construct and send:

- resource list with optional cursor;
- resource read;
- resource subscribe;
- prompt list with optional cursor;
- prompt get with arguments;
- logging level;
- generic notifications;
- initialized notification through the client API.

### JSON-RPC

Strict parsing now enforces:

- literal `jsonrpc: "2.0"`;
- present-versus-null identifier distinction;
- integer/string identifiers only;
- string methods;
- object/array params;
- exactly one response outcome;
- integer error codes;
- string error messages;
- preservation of optional error data.

The expanded tests discovered and removed direct map-index aborts in tool calls
and the echo reference callback.

## Engineering specification

The repository now has enforceable, reviewable policies for:

- top-level API documentation;
- warnings as errors;
- generated public interface snapshots;
- four-target portability;
- strict parser and callback failure behavior;
- tracked-file-only metrics;
- black-box wire verification;
- security boundaries and transport responsibilities;
- conventional focused commits;
- pull request evidence;
- release and rollback procedure.

`engineering_baseline.json` makes minimum evidence machine-checkable. CI checks out
full Git history so commit and contributor metrics are not corrupted by a shallow
clone.

## Documentation uplift

The documentation set covers audiences that a README alone cannot serve:

- users selecting supported features;
- implementers integrating transports;
- contributors extending protocol behavior;
- reviewers tracing evidence;
- operators defining limits and authorization;
- maintainers publishing releases;
- security reporters using a private channel.

Support claims are deliberately labeled Complete, Core, Constant, or Planned.
This mirrors the verification-first discipline of `moon_proto` without claiming
unimplemented MCP features.

## Test uplift

The verification stack now includes:

1. 161 MoonBit tests covering values, parser edges, lifecycle, clients, servers,
   framing, connections, tools, resources, prompts, logging, schema, errors, and
   transports;
2. execution on wasm, wasm-gc, JavaScript, and native;
3. 37 Python tests for fixture validation, recursive matching, reporting, file
   categorization, metric inspection, baselines, and repository aggregation;
4. 15 isolated black-box cases against the native echo executable;
5. a stateful NDJSON session fixture;
6. committed public interface snapshots;
7. a single release gate used locally and in CI.

## Remaining scope

Raw size is intentionally below `moon_proto` because the projects solve different
problems: `moon_proto` contains a parser, code generator, wire runtime,
cross-language oracles, many protobuf fixtures, and submission artifacts.
`moonbit_mcp` does not add duplicated or dead code to match that number.

The next substantive growth areas are:

- resource template expansion and list handler;
- pagination in high-level registries;
- roots client capability;
- sampling and elicitation host routers;
- bounded message buffers;
- production Streamable HTTP and WebSocket adapters;
- schema validation beyond the current builder subset.

Each should be added only with the same model, failure, end-to-end, target,
black-box, documentation, and security evidence established in this uplift.
