# Security Model

`moonbit_mcp` parses and routes messages; it does not make an MCP server safe by
itself. This document defines trust boundaries and the controls expected from a
host application or transport adapter.

## Trust boundaries

Treat all of these values as untrusted:

- raw JSON-RPC input;
- request identifiers;
- method names and parameters;
- tool arguments;
- resource URIs and template variables;
- prompt names and arguments;
- content metadata and base64 payloads;
- implementation names, titles, and versions;
- log data from a peer;
- transport session and authorization metadata.

Typed decoding proves shape, not authorization, intent, provenance, or safety.

## Responsibility split

| Control | SDK | Host/adapter |
|---|:---:|:---:|
| strict JSON-RPC shape | yes | may add tighter limits |
| request/response correlation | yes | cap pending requests |
| method dispatch | yes | choose exposed methods |
| authentication | no | required for remote access |
| authorization | no | required per tool/resource |
| argument schema enforcement | metadata | validate before callbacks |
| filesystem sandbox | no | constrain resource/tool code |
| network egress policy | no | constrain callbacks |
| rate limiting | no | per identity/session/method |
| message size limits | no | before buffering/parsing |
| secrets redaction | no | logging/telemetry layer |
| user approval | no | sensitive tools/sampling |
| audit logging | no | host policy |

## Tool callbacks

A tool callback is application code with the privileges of its host process.
Before invoking sensitive behavior:

1. authenticate the session;
2. authorize the tool for the identity;
3. validate arguments against a closed schema;
4. normalize paths, URLs, and identifiers;
5. apply rate, cost, and output limits;
6. request user approval where policy requires it;
7. execute with least operating-system privilege;
8. redact secrets from results and logs.

Tool annotations are hints to clients. `readOnlyHint`, `destructiveHint`, and
`idempotentHint` are not enforcement and must not replace server policy.

Never assemble shell commands by concatenating tool arguments. Prefer structured
process APIs with fixed executables and argument arrays. Apply an allowlist to
filesystem roots and network destinations.

## Resources

The high-level registry matches exact URIs and invokes only the callback stored
for that URI. It does not read files or fetch URLs automatically.

A callback that maps resource URIs to local paths must defend against:

- `..` traversal;
- percent-encoded traversal;
- symlink escape;
- case-folding differences;
- alternate path separators;
- device files and named pipes;
- oversized or changing files;
- time-of-check/time-of-use races.

Resolve a candidate path, compare it to an allowed root using platform-aware
path logic, then open it with the least privilege possible. Do not use string
prefix comparison for filesystem containment.

A callback that fetches URLs must defend against server-side request forgery:
allow schemes and destinations, resolve DNS safely, reject local/link-local and
metadata addresses, limit redirects, revalidate every redirect, and cap body
size and time.

Resource contents can contain instructions aimed at an AI model. Treat them as
data, label provenance, and keep them separate from trusted system policy.

## Prompts and content

Prompt arguments can be used for injection against templates or downstream
models. Avoid constructing trusted instructions by raw concatenation. Clearly
separate host-controlled instructions from user-controlled content and resource
text.

Base64 image, audio, and blob strings should be size-limited before decoding.
MIME types are peer-provided metadata and do not prove actual content type.
Downstream decoders may have their own vulnerabilities; keep them updated and
sandbox risky formats.

Resource links should be displayed and authorized before dereference. A URI name
or title can be misleading and must not override the actual destination.

## Transport controls

### Stdio

- Reserve stdout for JSON-RPC only.
- Send diagnostics to stderr.
- Run child servers with a minimal environment.
- Do not pass unrelated secrets through environment variables.
- close unused file descriptors;
- set process, memory, and execution-time limits where available.

### HTTP

- authenticate every session;
- verify authorization again for sensitive operations;
- validate `Origin` for browser-reachable endpoints;
- bind local-only servers to loopback rather than all interfaces;
- require appropriate content types;
- cap request and response bodies;
- use unpredictable session identifiers;
- expire idle sessions;
- prevent session fixation and cross-tenant lookup;
- use TLS outside a trusted local boundary.

### WebSocket

- authenticate the upgrade;
- validate origin and subprotocol;
- cap frame and assembled message sizes;
- reject unexpected binary frames;
- bound outbound queues;
- close on sustained protocol violations.

## Denial of service

`MessageBuffer` retains an unterminated tail. A transport adapter must impose a
maximum message length before feeding unlimited chunks. The core does not yet
expose a configurable buffer limit.

Also bound:

- JSON nesting and object size;
- pending client response map entries;
- stored notifications;
- concurrent callback executions;
- tool execution time;
- resource output size;
- prompt message count;
- log event size and rate;
- subscription count per session.

A timeout should cancel or isolate application work rather than merely abandon a
response while the work continues indefinitely.

## Error handling

Return stable, minimal peer-visible errors. Do not include stack traces, local
paths, credentials, raw database errors, environment values, or private network
information.

The SDK converts `McpError` messages directly to JSON-RPC error messages. Callback
code must therefore keep error details safe for the peer. Record sensitive
diagnostics only in a protected server-side channel with redaction.

Malformed messages produce an error response when possible. Repeated malformed
input can justify closing the transport at the adapter layer.

## Logging and telemetry

Default logs should contain:

- method name;
- outcome class;
- latency;
- bounded request/session correlation token;
- response/error code;
- redacted identity identifier if required.

Default logs should not contain:

- full tool arguments;
- prompt text;
- resource contents;
- embedded base64;
- authorization tokens;
- cookies;
- raw environment values;
- model conversations.

Make verbose wire logging opt-in, time-bounded, access-controlled, and visibly
marked unsafe for production data.

## Client safety

A client must not trust server metadata or tool annotations. Before calling a
server-provided tool, the host decides whether it is allowed and whether user
confirmation is required.

Server-initiated sampling and elicitation are not automatically answered by the
SDK. This is a deliberate policy boundary. A future host implementation must
apply model allowlists, token/cost limits, content review, user visibility, and
request provenance checks.

Cap the number of outstanding request identifiers. Discard or close on repeated
responses for unknown identifiers if the application policy treats them as
protocol abuse.

## Dependency and release hygiene

The root package depends on MoonBit core packages only. CI installs the MoonBit
toolchain and runs warnings-as-errors, all targets, conformance, and interface
snapshot checks.

Before release:

1. review the full dependency and workflow diff;
2. inspect generated `.mbti` changes;
3. run the release gate from a clean checkout;
4. review new callbacks for authorization and validation;
5. review fixtures for accidentally committed secrets;
6. update this model when a trust boundary changes.

## Reporting vulnerabilities

Do not publish exploit details in a public issue before a fix is available. Use
the repository security reporting channel described in `SECURITY.md`. Include the
affected commit, target, transport, minimal reproduction, impact, and suggested
mitigations when known.
