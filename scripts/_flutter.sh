#!/usr/bin/env bash
# Runs flutter/dart through FVM when available, plain binaries otherwise.
set -euo pipefail
cd "$(dirname "$0")/.."
tool="$1"; shift
if command -v fvm >/dev/null 2>&1; then exec fvm "$tool" "$@"; else exec "$tool" "$@"; fi
