# Release Process

## Version policy

The project uses semantic versioning for the published MoonBit package.

- patch: compatible fixes and documentation;
- minor: compatible public APIs or supported protocol features;
- major: breaking public API or behavior.

The supported MCP revision is versioned independently and appears in
`latest_protocol_version`.

## Release checklist

1. Confirm the intended branch and clean worktree.
2. Update `moon.mod` version.
3. Update `CHANGELOG.md` with user-visible changes and migration notes.
4. Update README test counts and protocol claims from actual output.
5. Run `moon info`; review and commit all `.mbti` changes.
6. Run `./scripts/release_gate.sh`.
7. Generate evidence:

   ```bash
   mkdir -p build
   python3 scripts/project_audit.py \
     --format markdown --output build/engineering-evidence.md
   python3 scripts/mcp_conformance.py run \
     --report build/conformance.json -- \
     moon run cmd/mcp-echo --target native
   ```

8. Review tracked files for secrets, local paths, and generated build output.
9. Create an annotated tag `vX.Y.Z`.
10. Publish through the MoonBit package workflow.
11. Verify installation from a clean consumer module.
12. Verify the CI badge and tag contents.

## Clean-checkout verification

Release evidence should come from a clone without an existing `_build` tree:

```bash
git clone --branch vX.Y.Z <repository> release-check
cd release-check
./scripts/release_gate.sh
```

Do not claim all-target results from cached output or a different commit.

## Rollback

Do not move a published tag. If a release is defective:

1. document the impact;
2. revert or fix on the main branch;
3. add a regression test;
4. publish a new patch version;
5. mark the affected release in the changelog.

## Evidence retention

CI logs, the conformance JSON report, generated interface diff, and engineering
audit are the minimum review evidence. Binary build directories are not tracked.
