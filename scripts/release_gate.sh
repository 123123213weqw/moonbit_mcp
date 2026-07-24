#!/bin/bash
set -e

echo "==> moon version"
moon version

echo "==> moon fmt --check"
moon fmt --check || { echo "Format check failed. Run 'moon fmt' to fix."; exit 1; }

echo "==> moon info (interface snapshot)"
moon info
git diff --exit-code -- pkg.generated.mbti || { echo "pkg.generated.mbti is out of date. Run 'moon info' and commit."; exit 1; }

echo "==> moon check --deny-warn"
moon check --deny-warn

echo "==> moon build"
moon build

echo "==> moon test --deny-warn"
moon test --deny-warn

echo "==> moon test --target all"
moon test --target all

echo ""
echo "✅ All release gate checks passed."
