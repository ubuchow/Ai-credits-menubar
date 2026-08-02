#!/usr/bin/env bash
set -euo pipefail
LABEL="com.github.ai-credits-menubar.combined"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
APP="$HOME/Applications/AI Credits.app"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pgrep -x AICredits >/dev/null 2>&1 && pgrep -x AICredits | xargs kill 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$APP"
echo "✓ AI Credits uninstalled"
