#!/usr/bin/env bash
set -euo pipefail
LABEL="com.github.ai-credits-menubar.grok"
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pgrep -x GrokCredits >/dev/null 2>&1 && pgrep -x GrokCredits | xargs kill 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/${LABEL}.plist"
rm -rf "$HOME/Applications/Grok Credits.app"
echo "✓ Grok Credits uninstalled"
