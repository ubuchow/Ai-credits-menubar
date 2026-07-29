#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources/main.swift"
APP_DIR="${HOME}/Applications/Codex Credits.app"
MACOS="$APP_DIR/Contents/MacOS"
BIN="$MACOS/CodexCredits"

RES="$APP_DIR/Contents/Resources"
mkdir -p "$MACOS" "$RES"
echo "→ Building Codex Credits…"
# Task sound effects (running loop + ended one-shot)
SOUNDS_DIR="$(cd "$ROOT/.." && pwd)/sounds"
if [[ -f "$SOUNDS_DIR/task-running.wav" && -f "$SOUNDS_DIR/task-ended.wav" ]]; then
  cp -f "$SOUNDS_DIR/task-running.wav" "$RES/task-running.wav"
  cp -f "$SOUNDS_DIR/task-ended.wav" "$RES/task-ended.wav"
else
  echo "⚠ sounds/ missing task-running.wav or task-ended.wav — build continues without audio assets" >&2
fi
# Low-memory usage counter (short-lived helper; keeps menubar RSS small)
if [[ -f "$ROOT/scripts/codex-usage-stats" ]]; then
  cp -f "$ROOT/scripts/codex-usage-stats" "$RES/codex-usage-stats"
  chmod +x "$RES/codex-usage-stats"
fi
swiftc -O -whole-module-optimization -o "$BIN" "$SRC" \
  -framework AppKit -framework Foundation -framework AVFoundation
chmod +x "$BIN"

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Codex Credits</string>
  <key>CFBundleDisplayName</key><string>Codex Credits</string>
  <key>CFBundleIdentifier</key><string>com.github.ai-credits-menubar.codex</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>CodexCredits</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
echo "✓ $APP_DIR"
