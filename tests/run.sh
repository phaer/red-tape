#!/usr/bin/env bash
# Run all red-tape tests using nix-unit
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== scan-dir tests ==="
nix-unit tests/scan-dir.nix

echo "=== transpose tests ==="
nix-unit tests/transpose.nix

echo "=== discover tests ==="
nix-unit tests/discover.nix

echo "=== integration tests ==="
nix-unit tests/integration.nix

echo "=== traditional mode tests ==="
nix-unit tests/traditional.nix

echo "=== memoization tests ==="
nix-unit tests/memoization.nix

echo ""
echo "All tests passed!"
