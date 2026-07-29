#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/grok/uninstall.sh"
"$ROOT/codex/uninstall.sh"
