#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${HOME}/Applications/AI Credits.app"
MACOS="$APP_DIR/Contents/MacOS"
RES="$APP_DIR/Contents/Resources"
BIN="$MACOS/AICredits"
REPO="$(cd "$ROOT/.." && pwd)"

mkdir -p "$MACOS" "$RES"
echo "→ Building AI Credits (Grok + Codex stacked)…"

# Sounds
if [[ -f "$REPO/sounds/task-running.wav" && -f "$REPO/sounds/task-ended.wav" ]]; then
  cp -f "$REPO/sounds/task-running.wav" "$RES/task-running.wav"
  cp -f "$REPO/sounds/task-ended.wav" "$RES/task-ended.wav"
fi
# Codex low-memory usage helper
if [[ -f "$REPO/codex/scripts/codex-usage-stats" ]]; then
  cp -f "$REPO/codex/scripts/codex-usage-stats" "$RES/codex-usage-stats"
  chmod +x "$RES/codex-usage-stats"
fi
# Grok credits helper copy for PATH-less environments
if [[ -f "$REPO/grok/scripts/grok-credits" ]]; then
  cp -f "$REPO/grok/scripts/grok-credits" "$RES/grok-credits"
  chmod +x "$RES/grok-credits"
fi
# Hermes (DeepSeek) balance helper
if [[ -f "$REPO/hermes/scripts/hermes-balance" ]]; then
  cp -f "$REPO/hermes/scripts/hermes-balance" "$RES/hermes-balance"
  chmod +x "$RES/hermes-balance"
fi
# App icon (G/H/C triangle)
ICON_SRC="$REPO/assets/AppIcon.icns"
if [[ ! -f "$ICON_SRC" && -f "$ROOT/scripts/generate-app-icon.py" ]]; then
  python3 "$ROOT/scripts/generate-app-icon.py" || true
fi
if [[ -f "$ICON_SRC" ]]; then
  cp -f "$ICON_SRC" "$RES/AppIcon.icns"
fi

swiftc -O -whole-module-optimization \
  -o "$BIN" \
  "$ROOT/Sources/Backends.swift" \
  "$ROOT/Sources/main.swift" \
  -framework AppKit -framework Foundation -framework AVFoundation
chmod +x "$BIN"

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>AI Credits</string>
  <key>CFBundleDisplayName</key><string>AI Credits</string>
  <key>CFBundleIdentifier</key><string>com.github.ai-credits-menubar.combined</string>
  <key>CFBundleVersion</key><string>2.1.0</string>
  <key>CFBundleShortVersionString</key><string>2.1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>AICredits</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
# Refresh Finder / Dock icon cache for this app
touch "$APP_DIR"
echo "✓ $APP_DIR"
