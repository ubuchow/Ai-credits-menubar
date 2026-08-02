#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
# Unified app
"$ROOT/combined/uninstall.sh" 2>/dev/null || true
# Legacy dual apps (if still present)
"$ROOT/grok/uninstall.sh" 2>/dev/null || true
"$ROOT/codex/uninstall.sh" 2>/dev/null || true
echo "✓ All AI Credits menu bar apps removed"
