#!/usr/bin/env bash
set -euo pipefail
LABEL="com.github.ai-credits-menubar.codex"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pgrep -x CodexCredits >/dev/null 2>&1 && pgrep -x CodexCredits | xargs kill 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/${LABEL}.plist"
rm -rf "$HOME/Applications/Codex Credits.app"
echo "✓ Codex Credits uninstalled"
