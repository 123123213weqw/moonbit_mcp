# Testing and Verification

The project uses layered verification so a passing unit suite cannot hide wire,
target, interface, fixture, or repository-quality regressions.

## Verification pyramid

```text
release gate
├── engineering evidence audit
├── black-box subprocess conformance
├── fixture schema validation
├── all-target MoonBit tests
├── default-target MoonBit tests
├── build and warnings-as-errors check
├── generated interface diff
└── formatter check
```

The canonical command is:

```bash
./scripts/release_gate.sh
```

Do not replace the full gate with a single `moon test` result in release notes.

## MoonBit tests

White-box files end in `_wbtest.mbt` and live beside the root package so they can
exercise private helpers and public behavior together.

| Suite | Primary scope |
|---|---|
| `mcp_wbtest.mbt` | base models, server, transports |
| `client_wbtest.mbt` | client requests, correlation, handshake |
| `framing_wbtest.mbt` | chunk boundaries and line endings |
| `connection_wbtest.mbt` | server connection wiring |
| `client_connection_wbtest.mbt` | client connection and loopback |
| `features_wbtest.mbt` | resources, prompts, logging requests |
| `protocol_conformance_wbtest.mbt` | strict JSON-RPC edge behavior |
| `model_wbtest.mbt` | exhaustive value, error, schema, transport checks |

Run the default target with warnings denied:

```bash
moon test --deny-warn
```

Run portable behavior on every supported backend:

```bash
moon test --target all
```

A target-specific failure is a release blocker even if the preferred wasm-gc
target passes.

### Test style

- Use behavior-focused names: `"client correlates out-of-order responses"`.
- Keep arrange, act, and assert visible in the test.
- Assert protocol structure, not JSON object key order.
- Test both success and failure paths for every parser or callback boundary.
- Add regression tests before fixing a reported crash.
- Avoid wall clocks, random values, network calls, and shared global state.
- Use `InMemoryTransport` for full synchronous sessions.
- Use `BufferedTransport` when only outbound shape matters.

### Required cases for a new request builder

1. method name is correct;
2. required parameters are encoded;
3. optional parameters are omitted when absent;
4. identifiers increase monotonically;
5. the matching `ClientConnection::send_*` uses the transport;
6. an end-to-end server result correlates to the returned identifier.

### Required cases for a new server handler

1. capability advertisement;
2. list or discovery result;
3. successful callback execution;
4. missing target;
5. missing required parameter;
6. wrong parameter type;
7. callback error conversion;
8. notification/no-response behavior when applicable.

## Strict parser coverage

The JSON-RPC suite verifies:

- malformed JSON and top-level scalar/array rejection;
- required `jsonrpc: "2.0"`;
- integer and string identifiers;
- rejection of null, Boolean, and fractional identifiers;
- string methods;
- object/array parameters;
- result/error exclusivity;
- integer error codes and string messages;
- optional error data retention;
- null success results;
- escaped string encoding;
- out-of-order response correlation;
- one-shot result consumption.

When relaxing the parser for compatibility, add a fixture proving the peer
behavior and document the deviation in `PROTOCOL_SUPPORT.md`.

## Black-box conformance

`scripts/mcp_conformance.py` validates an executable through newline-delimited
stdin/stdout. It uses a JSON suite at
`tests/conformance/server_cases.json` and the Python standard library only.

Validate fixture structure:

```bash
python3 scripts/mcp_conformance.py validate
```

List cases:

```bash
python3 scripts/mcp_conformance.py list
```

Run the reference server:

```bash
python3 scripts/mcp_conformance.py run --timeout 10 -- \
  moon run cmd/mcp-echo --target native
```

Write machine-readable evidence:

```bash
python3 scripts/mcp_conformance.py run \
  --report build/conformance.json \
  -- ./your-server
```

Each case starts an isolated process. This prevents state leakage and supports
native runtimes that flush output only when stdin closes. Stateful lifecycle
coverage is provided by loopback tests and `tests/fixtures/session.ndjson`.

### Fixture schema

A case has:

```json
{
  "id": "ping-no-params",
  "input": {"jsonrpc":"2.0","id":1,"method":"ping"},
  "expect": {"jsonrpc":"2.0","id":1,"result":{}}
}
```

Expected objects are recursive subsets. This lets a fixture assert required
members without rejecting compatible metadata. Arrays compare by expected
prefix unless their dot path appears in `ignoreArrayContentsAt`.

Notification cases use `"noResponse": true` instead of `expect`.

### Adding fixtures

- Choose a stable, descriptive, unique id.
- Use JSON values rather than stringified JSON.
- Assert the narrowest result that proves compatibility.
- Never ignore an entire response to make a failing implementation pass.
- Keep server-specific tool names out of generic cases unless the suite targets
  the repository echo server.
- Run `validate` before committing.

## Public interface verification

`moon info` regenerates `.mbti` snapshots. The gate checks every tracked snapshot:

```bash
moon info
git diff --exit-code -- '*.mbti'
```

Review interface diffs as API changes. A snapshot must never be updated merely to
silence CI without checking visibility, names, field mutability, and types.

## Engineering audit

`scripts/project_audit.py` measures only tracked files. Ignored build output
cannot inflate line or test counts.

```bash
python3 scripts/project_audit.py
python3 scripts/project_audit.py --check
python3 scripts/project_audit.py --format markdown --output build/evidence.md
python3 scripts/project_audit.py --format json --files
```

`engineering_baseline.json` declares the minimum evidence floor derived from the
`moon_proto` engineering standard. Raising a floor is compatible. Lowering one
requires an explicit rationale in the pull request and changelog.

Metrics are evidence, not substitutes for review. Generated duplication, empty
tests, vendored data, and verbose comments must not be added merely to satisfy a
number.

## Manual smoke tests

Run the loopback demo:

```bash
moon run cmd/mcp-loopback --target native
```

Send a session transcript to the echo server:

```bash
moon run cmd/mcp-echo --target native < tests/fixtures/session.ndjson
```

Expected behavior:

- initialize returns server metadata and capabilities;
- initialized emits no line;
- tools list contains `echo`;
- the echo call contains `fixture hello`;
- resource and prompt lists are valid arrays;
- ping returns an empty object.

## Failure triage

1. Formatter failure: run `moon fmt`, inspect the diff.
2. Interface failure: run `moon info`, review API changes.
3. Warning failure: fix the warning; do not weaken `--deny-warn`.
4. One backend failure: minimize backend-specific code and reproduce that target.
5. Conformance failure: replay the printed input directly against the executable.
6. Audit failure: inspect the named metric and add real missing evidence.
7. Nondeterminism: remove timing/network/global state before retrying.

Record exact commands and tool versions in bug reports.
