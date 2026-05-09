#!/usr/bin/env bash
# shellcheck shell=bash
# Test runner for send-to-sftp
# Uses bats-core (install via: sudo apt install bats or use vendored)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for bats
if ! command -v bats &>/dev/null; then
    echo "Error: bats not found. Install with:" >&2
    echo "  sudo apt install bats" >&2
    echo "  # or" >&2
    echo "  npm install -g bats" >&2
    exit 1
fi

echo "Running send-to-sftp test suite..."
echo "================================"

# Run all .bats files
bats "${SCRIPT_DIR}"/*.bats
