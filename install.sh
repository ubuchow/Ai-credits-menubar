#!/usr/bin/env bash
# Install unified AI Credits menubar (Grok + Codex stacked)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$ROOT"/combined/*.sh "$ROOT"/grok/*.sh "$ROOT"/codex/*.sh \
  "$ROOT"/grok/scripts/grok-credits "$ROOT"/codex/scripts/codex-usage-stats \
  "$ROOT"/hermes/scripts/hermes-balance 2>/dev/null || true
"$ROOT/combined/install.sh"
echo
echo "Done. Look for the triangle chip: G (top) · H · C in the menu bar."
