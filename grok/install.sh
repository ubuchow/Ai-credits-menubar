#!/usr/bin/env bash
# Install Grok Credits menu bar app + grok-credits helper + login item
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.github.ai-credits-menubar.grok"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
APP="$HOME/Applications/Grok Credits.app"
LOG="$HOME/Library/Logs/GrokCreditsMenuBar"
HELPER_DIR="$HOME/.local/bin"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG" "$HELPER_DIR" "$HOME/.grok/bin" \
  "$HOME/Applications"

if ! command -v python3 >/dev/null 2>&1; then
  echo "✗ 需要 python3（macOS 可先安装：xcode-select --install 或 brew install python）"
  exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
  echo "✗ 需要 swiftc。请执行：xcode-select --install"
  exit 1
fi

# Install helper used by the app (reads ~/.grok/auth.json at runtime on this machine)
install -m 0755 "$ROOT/scripts/grok-credits" "$HELPER_DIR/grok-credits"
# Also drop a copy where Grok CLI users expect tools
install -m 0755 "$ROOT/scripts/grok-credits" "$HOME/.grok/bin/grok-credits" 2>/dev/null || true

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
    <key>PATH</key><string>${HOME}/.local/bin:${HOME}/.grok/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    <key>GROK_HOME</key><string>${HOME}/.grok</string>
  </dict>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pgrep -x GrokCredits >/dev/null 2>&1 && pgrep -x GrokCredits | xargs kill 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null || true
open -a "$APP" 2>/dev/null || true

echo "✓ Grok Credits installed"
echo "  App: $APP"
echo "  Requires: Grok Build login (local ~/.grok/auth.json — never committed)"
