# Development Guide

## Prerequisites

- Git;
- a current MoonBit toolchain;
- Python 3.9 or newer for verification scripts;
- a POSIX shell for the release gate.

Confirm versions:

```bash
moon version --all
python3 --version
git --version
```

## First checkout

```bash
git clone https://github.com/123123213weqw/moonbit_mcp.git
cd moonbit_mcp
moon update
./scripts/release_gate.sh
```

If the full gate fails before a change, record the exact baseline rather than
silently weakening checks.

## Source layout

Core `.mbt` files remain flat in the root package. Use feature-specific names and
avoid a generic utilities file. Runtime executables live under `cmd/`, fixtures
under `tests/`, verification tools under `scripts/`, and design material under
`docs/`.

Every top-level MoonBit definition has a `///|` documentation marker. Public
structs/enums derive `Debug` and `Eq` when their fields support those traits.
Prefer `priv` or a file-local function for implementation helpers.

## Change workflow

1. Create a focused branch.
2. Add or update a failing test/fixture.
3. Implement the narrowest complete behavior.
4. Run `moon fmt`.
5. Run focused tests, then the full gate.
6. Run `moon info` and review interface changes.
7. Update protocol/support/security documentation when claims change.
8. Commit one logical change with a conventional subject.

Recommended commit prefixes:

- `feat(scope):` compatible capability;
- `fix(scope):` defect correction;
- `test(scope):` verification only;
- `docs(scope):` documentation only;
- `chore(scope):` automation or repository maintenance;
- `refactor(scope):` behavior-preserving structure change.

Keep feature, tests, and documentation reviewable. A small sequence of honest
commits is preferable to one opaque dump or artificial history padding.

## MoonBit conventions

- Return `Result` for peer/input failures.
- Do not use exceptions as normal protocol control flow.
- Match optional map members with `get`; direct indexing can abort when absent.
- Preserve string versus integer request identifier types.
- Do not rely on JSON object key order.
- Keep transport/runtime APIs out of portable model files.
- Use fluent builders only when mutation is explicit and local.
- Add public API documentation before regenerating interfaces.

## Adding a protocol feature

1. Add method constants in `protocol.mbt`.
2. Model reusable data in a feature file.
3. Implement `to_json` and strict parsing where needed.
4. Add low-level client builders.
5. Add connection forwarding helpers.
6. Add a server handler or high-level registry only for common behavior.
7. Add success, malformed-input, unknown-target, and end-to-end tests.
8. Add black-box cases when the reference executable exposes the feature.
9. Update `docs/PROTOCOL_SUPPORT.md`.
10. Regenerate and inspect `pkg.generated.mbti`.

## Avoiding crashes on JSON

Do not write:

```moonbit
let name = object["name"]
```

for peer-controlled JSON. A missing key can abort. Use:

```moonbit
let name = match object.get("name") {
  Some(String(value)) => value
  _ => return Err(InvalidArguments("name must be a string"))
}
```

Add a regression case that omits the member and another that supplies the wrong
type.

## Documentation expectations

A user-visible feature needs:

- a README entry or linked guide;
- support-matrix status;
- runnable example or exact wire example;
- error behavior;
- security/limit notes;
- tests referenced as evidence.

Commands in documentation must work from the repository root.

## Generated interfaces

Run:

```bash
moon info
git diff -- '*.mbti'
```

Review additions and removals. Unexpected public fields often indicate missing
visibility decisions. Commit generated snapshots in the same logical change as
the public API.

## Performance work

Measure before optimizing. Keep representative messages and record:

- target backend;
- toolchain revision;
- payload size and shape;
- warmup policy;
- iteration count;
- allocation or memory observations;
- before/after results.

Performance changes must preserve strict parser tests and all-target behavior.
Do not replace safe map access with aborting access for microbenchmarks.

## Pull request readiness

Before requesting review:

- the worktree contains no build output or secrets;
- the release gate passes;
- interface diffs are intentional;
- new public APIs are documented;
- protocol claims are conservative;
- security boundaries are called out;
- commits are focused and explain the evolution;
- the PR template is completed with exact commands and results.
