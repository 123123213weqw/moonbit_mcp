## Problem

<!-- What user, protocol, or maintenance problem does this solve? -->

## Approach

<!-- Describe the design and why this layer owns the behavior. -->

## Protocol and API impact

- [ ] No public API change
- [ ] `pkg.generated.mbti` reviewed and updated
- [ ] `docs/PROTOCOL_SUPPORT.md` updated
- [ ] Migration or compatibility notes included

## Verification

<!-- Paste exact commands and summaries; do not write only “tests pass”. -->

- [ ] `moon fmt --check`
- [ ] `moon check --deny-warn`
- [ ] `moon test --deny-warn`
- [ ] `moon test --target all`
- [ ] black-box conformance (when applicable)
- [ ] `./scripts/release_gate.sh`

## Security and operations

<!-- Trust boundaries, limits, authorization, sensitive logging, adapter impact. -->

- [ ] Peer-controlled map access cannot abort on missing members
- [ ] Inputs and outputs have an owner for size/time limits
- [ ] No secrets, local environment files, or build artifacts are included
- [ ] `docs/SECURITY_MODEL.md` reviewed when the boundary changes

## Documentation

- [ ] README or user guide updated
- [ ] tests/fixtures are described
- [ ] changelog updated for user-visible behavior

## Commit structure

<!-- Explain the focused commit sequence or why a single commit is appropriate. -->
