# Security Policy

## Supported versions

Security fixes are applied to the latest release line and the main branch. Older
minor versions may require upgrading when a fix changes protocol validation or a
public API.

## Reporting

Use GitHub's private vulnerability reporting feature for this repository when
available. Do not open a public issue containing an unpatched vulnerability.

Include:

- affected version and commit;
- MoonBit target and toolchain version;
- transport/runtime context;
- minimal reproduction or fixture;
- impact and required preconditions;
- whether secrets or personal data are involved;
- suggested mitigation if known;
- a safe contact channel for follow-up.

Reports that demonstrate a crash on malformed JSON, authorization bypass in a
shipped adapter, cross-session state leak, unbounded memory growth, or unsafe
resource/tool behavior receive priority.

## Response process

Maintainers will validate the report, determine affected versions, prepare tests
and a fix, run the complete release gate, publish a new release, and coordinate
disclosure. Timelines depend on impact and reproduction quality.

## Scope

The portable SDK provides message validation and routing. Authentication,
authorization, resource access, tool sandboxing, rate limits, and transport
session policy are host responsibilities. See `docs/SECURITY_MODEL.md` for the
complete boundary.

A host-policy mistake is still useful to report when repository examples or
documentation encourage it.
