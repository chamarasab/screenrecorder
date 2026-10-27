#!/bin/bash
set -e

echo "🔨 Building ScreenRecorder in Release mode..."
swift build -c release

APP_DIR="ScreenRecorder.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Assembling $APP_DIR bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp .build/release/ScreenRecorder "$MACOS_DIR/ScreenRecorder"

# Copy Icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ScreenRecorder</string>
    <key>CFBundleIdentifier</key>
    <string>com.chamara.ScreenRecorder</string>
    <key>CFBundleName</key>
    <string>ScreenRecorder</string>
    <key>CFBundleDisplayName</key>
    <string>ScreenRecorder Studio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>ScreenRecorder requires screen recording permission to capture your display video and internal macOS system audio.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>ScreenRecorder requires microphone permission if voiceover recording is enabled.</string>
    <key>NSCameraUsageDescription</key>
    <string>ScreenRecorder requires camera access to display your floating webcam preview overlay while recording.</string>
</dict>
</plist>
EOF

# Sign bundle ad-hoc so macOS Gatekeeper trusts it completely
echo "✍️ Signing application bundle..."
codesign --force --deep --sign - "$APP_DIR"
xattr -cr "$APP_DIR" || true

echo "✅ Successfully packaged and signed ScreenRecorder.app with custom icon!"
echo "📍 Location: $(pwd)/$APP_DIR"
