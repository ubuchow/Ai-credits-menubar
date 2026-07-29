#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.github.ai-credits-menubar.codex"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
APP="$HOME/Applications/Codex Credits.app"
LOG="$HOME/Library/Logs/CodexCreditsMenuBar"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG" "$HOME/Applications"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "✗ 需要 swiftc。请执行：xcode-select --install"
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "✗ 需要 sqlite3（macOS 自带，若缺失请检查系统）"
  exit 1
fi

"$ROOT/build.sh"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-W</string>
    <string>-a</string>
    <string>${APP}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>StandardOutPath</key><string>${LOG}/stdout.log</string>
  <key>StandardErrorPath</key><string>${LOG}/stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key><string>${HOME}</string>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    <key>CODEX_HOME</key><string>${HOME}/.codex</string>
  </dict>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pgrep -x CodexCredits >/dev/null 2>&1 && pgrep -x CodexCredits | xargs kill 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null || true
open -a "$APP" 2>/dev/null || true

echo "✓ Codex Credits installed"
echo "  App: $APP"
echo "  Requires: Codex/ChatGPT login (local ~/.codex/auth.json — never committed)"
