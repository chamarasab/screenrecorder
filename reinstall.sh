#!/bin/bash
set -e

echo "🛑 1. Uninstalling existing ScreenRecorder and cleaning TCC permissions..."
killall ScreenRecorder 2>/dev/null || true
sleep 1

tccutil reset ScreenCapture com.chamara.ScreenRecorder 2>/dev/null || true
tccutil reset Camera com.chamara.ScreenRecorder 2>/dev/null || true
tccutil reset Microphone com.chamara.ScreenRecorder 2>/dev/null || true

rm -rf /Applications/ScreenRecorder.app
rm -rf ScreenRecorder.app

echo "🔨 2. Building fresh Release binary with Apple Silicon optimizations..."
swift build -c release

APP_DIR="ScreenRecorder.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 3. Assembling application bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/ScreenRecorder "$MACOS_DIR/ScreenRecorder"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

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
    <key>CFBundleVersion</key>
    <string>1</string>
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

echo "✍️ 4. Codesigning bundle with stable designated identifier..."
codesign --force --deep -s - -r="designated => identifier \"com.chamara.ScreenRecorder\"" "$APP_DIR"
xattr -cr "$APP_DIR" || true

echo "🚀 5. Installing clean app directly into /Applications/ScreenRecorder.app..."
cp -R "$APP_DIR" /Applications/ScreenRecorder.app
xattr -cr /Applications/ScreenRecorder.app

echo "📋 6. Registering with macOS LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ScreenRecorder.app

echo "🎉 7. Launching newly installed ScreenRecorder Studio..."
open /Applications/ScreenRecorder.app

echo "✅ Reinstallation complete! ScreenRecorder is now freshly installed in /Applications/."
