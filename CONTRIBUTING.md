# Contributing

Thank you for improving `moonbit_mcp`. Contributions are evaluated on protocol
correctness, portability, verification evidence, API clarity, and conservative
compatibility claims.

## Before opening work

- Search existing issues and pull requests.
- For a public API or protocol-scope change, open a proposal issue first.
- For a security vulnerability, follow `SECURITY.md` instead of a public issue.
- Keep the change focused enough to review and revert independently.

## Local verification

Install Git, Python 3.9+, and a current MoonBit toolchain. From the repository
root run:

```bash
./scripts/release_gate.sh
```

The gate is the definition of release-ready verification. It formats, checks
warnings, builds, tests every target, validates generated interfaces and fixtures,
runs black-box conformance, and enforces the engineering evidence floor.

For a faster development loop:

```bash
moon fmt
moon check --deny-warn
moon test --deny-warn
```

Always run the complete gate before requesting review.

## Change requirements

### Fix

- add a regression test that fails without the fix;
- explain root cause rather than only the symptom;
- preserve peer-visible identifiers and error semantics;
- update security notes if a trust boundary was involved.

### Feature

- document wire behavior and unsupported edges;
- add unit, failure-path, and end-to-end coverage;
- add black-box fixtures when the reference server exposes it;
- update `docs/PROTOCOL_SUPPORT.md`;
- regenerate and review `.mbti` files;
- update README and changelog when user-visible.

### Documentation

- use commands that run from repository root;
- distinguish implemented, core-only, and planned behavior;
- link to source/tests as evidence where helpful;
- avoid claims derived only from line or commit counts.

## Code conventions

- Every top-level MoonBit definition begins with `///|`.
- Use `Result[..., McpError]` for invalid peer input.
- Never index optional peer-controlled map fields directly; use `get` and match.
- Do not depend on JSON object member order.
- Keep operating-system and network code outside the portable root package.
- Prefer small feature-specific files over a generic utilities module.
- Public structs and enums derive `Debug` and `Eq` when possible.
- Add target guards around native-only FFI.
- Keep diagnostics off a protocol stdout stream.

## Tests and fixtures

Test names describe behavior, not implementation. Cover valid input, absent
members, wrong types, unknown targets, callback errors, and lifecycle behavior.
Use `InMemoryTransport` for deterministic sessions and `BufferedTransport` for
outbound request assertions.

Fixture expectations are recursive subsets. Assert enough to prove compatibility
without depending on key order or unrelated optional metadata.

Do not add empty, duplicated, or generated tests to increase a metric. The audit
floor is evidence coverage, not a target to game.

## Public API snapshots

After public API changes:

```bash
moon info
git diff -- '*.mbti'
```

Review every change. Call out additions, removals, field mutability changes, and
migration impact in the pull request.

## Commits

Use focused conventional subjects, for example:

```text
feat(client): add paginated resource request
fix(jsonrpc): reject null request identifiers
test(conformance): cover Unicode tool arguments
docs(security): document URI access policy
```

Avoid unrelated formatting churn. Do not rewrite shared history after review has
started unless reviewers agree.

## Pull requests

Complete the template with:

- problem and approach;
- protocol/API impact;
- exact commands and results;
- generated interface diff status;
- security and compatibility considerations;
- documentation updated;
- focused commit sequence.

Reviewers may request the change be split when behavior, refactoring, and mass
documentation are mixed.

## Developer Certificate of Origin

By contributing, you certify that you have the right to submit the work under the
repository license and that the contribution may be redistributed under it.
