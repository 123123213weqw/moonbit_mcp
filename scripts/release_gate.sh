#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

step() { printf '\n==> %s\n' "$*"; }

step "tool versions"
moon version
python3 --version
git --version

step "format check"
moon fmt --check

step "public interface snapshots"
moon info
git diff --exit-code -- '*.mbti'

step "warnings-as-errors check"
moon check --deny-warn

step "build"
moon build

step "unit and integration tests"
moon test --deny-warn

step "all MoonBit targets"
moon test --target all

step "Python syntax"
python3 -m compileall -q scripts

step "conformance fixture schema"
python3 scripts/mcp_conformance.py validate

step "black-box echo conformance"
python3 scripts/mcp_conformance.py run --timeout 10 -- moon run cmd/mcp-echo --target native

step "engineering evidence floor"
python3 scripts/project_audit.py --check

printf '\nAll release gate checks passed.\n'
