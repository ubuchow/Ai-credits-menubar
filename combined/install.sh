#!/usr/bin/env bash
# Install unified AI Credits menubar (Grok + Codex stacked in one slot)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
LABEL="com.github.ai-credits-menubar.combined"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
APP="$HOME/Applications/AI Credits.app"
LOG="$HOME/Library/Logs/AICreditsMenuBar"
HELPER_DIR="$HOME/.local/bin"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG" "$HELPER_DIR" "$HOME/.grok/bin" "$HOME/Applications"

if ! command -v python3 >/dev/null 2>&1; then
  echo "✗ 需要 python3"
  exit 1
fi
if ! command -v swiftc >/dev/null 2>&1; then
  echo "✗ 需要 swiftc。请执行：xcode-select --install"
  exit 1
fi

# Stop & remove legacy dual apps so only one slot remains
for old in \
  com.github.ai-credits-menubar.grok \
  com.github.ai-credits-menubar.codex
do
  launchctl bootout "gui/$(id -u)/${old}" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/${old}.plist"
done
pgrep -x GrokCredits >/dev/null 2>&1 && pgrep -x GrokCredits | xargs kill 2>/dev/null || true
pgrep -x CodexCredits >/dev/null 2>&1 && pgrep -x CodexCredits | xargs kill 2>/dev/null || true
rm -rf "$HOME/Applications/Grok Credits.app" "$HOME/Applications/Codex Credits.app" 2>/dev/null || true

# Helpers used at runtime
install -m 0755 "$REPO/grok/scripts/grok-credits" "$HELPER_DIR/grok-credits"
install -m 0755 "$REPO/grok/scripts/grok-credits" "$HOME/.grok/bin/grok-credits" 2>/dev/null || true
install -m 0755 "$REPO/codex/scripts/codex-usage-stats" "$HELPER_DIR/codex-usage-stats" 2>/dev/null || true

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
    <key>CODEX_HOME</key><string>${HOME}/.codex</string>
  </dict>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
pgrep -x AICredits >/dev/null 2>&1 && pgrep -x AICredits | xargs kill 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null || true
open -a "$APP" 2>/dev/null || true

echo "✓ AI Credits installed (Grok + Codex stacked in one menu bar slot)"
echo "  App: $APP"
echo "  Menubar: stacked G/C mark + stacked dual % chip (G top · C bottom)"
echo "  Legacy Grok Credits / Codex Credits apps were removed to free the second slot."
