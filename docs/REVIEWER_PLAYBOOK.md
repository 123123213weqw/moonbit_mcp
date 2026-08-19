# Reviewer Playbook

This walkthrough lets a reviewer assess the project in roughly ten minutes,
then continue into deeper implementation and security review.

## Minute 0–1: scope

Read the README feature table and `PROTOCOL_SUPPORT.md`. Confirm that claims are
split into Complete, Core, Constant, and Planned rather than implying full MCP
coverage.

Key scope:

- MCP revision `2025-06-18`;
- portable MoonBit server and client core;
- strict JSON-RPC parsing;
- tools, concrete resources, and prompts registries;
- transport-neutral connections;
- native stdio reference server;
- all-target test suite and black-box conformance.

## Minute 1–3: run the gate

```bash
./scripts/release_gate.sh
```

Expected stages:

1. tool versions;
2. formatter;
3. generated public interfaces;
4. warnings-as-errors type check;
5. build;
6. default tests;
7. wasm, wasm-gc, JavaScript, native tests;
8. Python syntax;
9. fixture validation;
10. black-box executable cases;
11. engineering evidence floors.

Any skipped stage changes the evidence claim.

## Minute 3–4: inspect metrics

```bash
python3 scripts/project_audit.py --format markdown
```

The counter reads only `git ls-files`; ignored `_build` output cannot inflate
results. Compare actual values to `engineering_baseline.json`. Metrics are a
minimum floor, not a quality score.

Confirm commit history is composed of focused feature, fix, test, documentation,
and automation changes:

```bash
git log --oneline --decorate -20
```

## Minute 4–5: run wire behavior

```bash
python3 scripts/mcp_conformance.py run -- \
  moon run cmd/mcp-echo --target native
```

Inspect `tests/conformance/server_cases.json`. Cases cover initialization,
notifications, ping, tool list/call, Unicode, missing targets, resources, prompts,
and identifier preservation.

Manual transcript:

```bash
moon run cmd/mcp-echo --target native < tests/fixtures/session.ndjson
```

There should be one fewer output line than input lines because the initialized
notification has no response.

## Minute 5–6: inspect strict parsing

Open `jsonrpc.mbt` and `protocol_conformance_wbtest.mbt`. Look for:

- literal protocol version validation;
- distinction between absent and null identifiers;
- object/array-only params;
- exact result/error exclusivity;
- error data preservation;
- no direct indexing of optional peer members;
- out-of-order client correlation.

A useful mutation test is to change `"2.0"` to `"1.0"` in a fixture and confirm
validation fails.

## Minute 6–7: inspect end-to-end architecture

Open `client_connection_wbtest.mbt`, especially the loopback test. It creates:

- a high-level echo server;
- server and client connections;
- an in-memory transport pair;
- initialize and initialized exchange;
- tool discovery;
- tool invocation and correlated response.

This proves layers compose without a platform runtime.

## Minute 7–8: inspect public API

```bash
moon info
git diff --exit-code -- '*.mbti'
```

Review `pkg.generated.mbti` as the published contract. Check that new public types
have docs, appropriate field mutability, and predictable error results.

## Minute 8–9: inspect security boundaries

Read `SECURITY_MODEL.md`. Verify the project does not claim to provide:

- authentication or authorization;
- filesystem or network sandboxing;
- schema enforcement;
- HTTP origin/session handling;
- automatic approval for sensitive tools;
- automatic sampling or elicitation answers.

Inspect callbacks for direct map indexing, path access, shell execution, secret
logging, and unbounded buffers.

## Minute 9–10: inspect portability

```bash
moon test --target all
```

Native-only FFI should be guarded by target configuration under `cmd/`. Core
protocol, client, server, content, and connection files should remain free of
operating-system dependencies.

## Deeper review prompts

### Correctness

- Can a missing JSON member abort rather than return `McpError`?
- Are string request identifiers preserved exactly?
- Can a response contain both `result` and `error`?
- Does a notification ever produce output?
- Is a response removed after consumption?
- Do callbacks receive object arguments or a validated failure?

### API design

- Is the feature implemented at the correct layer?
- Does a public helper reduce repeated correct code?
- Is raw JSON retained where the protocol is extensible?
- Did interface regeneration expose accidental fields?
- Is unsupported behavior clearly labeled?

### Verification

- Does the regression test fail on the parent commit?
- Is the black-box fixture independent of JSON key order?
- Are error paths covered?
- Do all four targets pass?
- Can generated or ignored files inflate the reported metric?

### Operations

- Where are message and output sizes capped?
- Does the runtime flush protocol output?
- Are diagnostics isolated from stdout?
- How are sessions authenticated and expired?
- How are sensitive arguments and resource contents redacted?

## Acceptance criteria

A change is ready when:

- public behavior matches the support matrix;
- parser and callback boundaries fail safely;
- focused and end-to-end tests exist;
- all supported targets pass;
- black-box fixtures pass where applicable;
- generated interfaces are current;
- security responsibilities are documented;
- the full release gate succeeds from the reviewed commit.
