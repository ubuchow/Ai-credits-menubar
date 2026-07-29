#!/usr/bin/env bash
# Install both menu bar apps (macOS 13+)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$ROOT"/grok/*.sh "$ROOT"/codex/*.sh "$ROOT"/grok/scripts/grok-credits 2>/dev/null || true
"$ROOT/grok/install.sh"
"$ROOT/codex/install.sh"
echo
echo "Done. Look for  G xx%  and  C xx%  in the macOS menu bar."
