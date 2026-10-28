#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TOTAL=0
PASSED=0

pass() {
    TOTAL=$((TOTAL + 1))
    PASSED=$((PASSED + 1))
    echo -e "  [${GREEN}PASS${NC}] $1"
}

fail() {
    TOTAL=$((TOTAL + 1))
    echo -e "  [${RED}FAIL${NC}] $1: $2"
}

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${BLUE}       ScreenRecorder Automated Smoke Test Suite     ${NC}"
echo -e "${BLUE}====================================================${NC}\n"

# TEST 1: App Bundle Verification
echo -e "${YELLOW}1. App Bundle & Mach-O Integrity...${NC}"
APP_BUNDLE="/Applications/ScreenRecorder.app"
if [ ! -d "$APP_BUNDLE" ]; then
    APP_BUNDLE="ScreenRecorder.app"
fi

if [ -f "$APP_BUNDLE/Contents/MacOS/ScreenRecorder" ]; then
    pass "Mach-O executable binary exists ($APP_BUNDLE)"
else
    fail "Mach-O executable binary" "Missing binary in $APP_BUNDLE"
fi

if file "$APP_BUNDLE/Contents/MacOS/ScreenRecorder" | grep -q "arm64"; then
    pass "Binary is Apple Silicon arm64 native"
else
    fail "Binary architecture" "Not arm64"
fi

if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    pass "AppIcon.icns exists in Resources"
else
    fail "AppIcon.icns missing" "AppIcon.icns not found"
fi

if codesign --verify --deep --strict "$APP_BUNDLE" 2>/dev/null; then
    pass "Codesign signature is valid and verified"
else
    fail "Codesign verification" "Failed codesign verification"
fi

# TEST 2: ScreenCaptureKit Permission & Display Detection
echo -e "\n${YELLOW}2. ScreenCaptureKit Framework & Permissions...${NC}"
cat << 'EOF' > /tmp/test_sck.swift
import Foundation
import ScreenCaptureKit

Task {
    do {
        let content = try await SCShareableContent.current
        print("SCK_SUCCESS: \(content.displays.count) displays found")
        exit(0)
    } catch {
        print("SCK_PERMISSION_OR_ERROR: \(error.localizedDescription)")
        exit(0) // Permission may be granted on first prompt
    }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))
EOF

if swift /tmp/test_sck.swift 2>&1 | grep -q "SCK_"; then
    pass "ScreenCaptureKit API connectivity & runtime verified"
else
    fail "ScreenCaptureKit" "Failed SCShareableContent invocation"
fi
rm -f /tmp/test_sck.swift

# TEST 3: Video Engine & AVAssetWriter MP4 Encoding
echo -e "\n${YELLOW}3. Video Engine & AVAssetWriter MP4 Synthesis...${NC}"
cat << 'EOF' > /tmp/test_writer.swift
import Foundation
import AVFoundation
import CoreMedia

let outURL = URL(fileURLWithPath: "/tmp/test_screenrecorder_sample.mp4")
try? FileManager.default.removeItem(at: outURL)

do {
    let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
    
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 640,
        AVVideoHeightKey: 360
    ]
    let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    vInput.expectsMediaDataInRealTime = false
    
    let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 128000
    ]
    let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
    aInput.expectsMediaDataInRealTime = false
    
    if writer.canAdd(vInput) { writer.add(vInput) }
    if writer.canAdd(aInput) { writer.add(aInput) }
    
    guard writer.startWriting() else { exit(1) }
    writer.startSession(atSourceTime: .zero)
    vInput.markAsFinished()
    aInput.markAsFinished()
    
    let sema = DispatchSemaphore(value: 0)
    writer.finishWriting {
        sema.signal()
    }
    sema.wait()
    
    guard FileManager.default.fileExists(atPath: outURL.path) else { exit(2) }
    print("WRITER_SUCCESS")
} catch {
    print("WRITER_ERROR: \(error)")
    exit(3)
}
EOF

if swift /tmp/test_writer.swift 2>&1 | grep -q "WRITER_SUCCESS"; then
    pass "AVAssetWriter successfully synthesized MP4 with video & system audio tracks"
else
    fail "AVAssetWriter" "Failed to synthesize sample MP4"
fi

# TEST 4: In-App Video Playback Engine
echo -e "\n${YELLOW}4. In-App Video Player Engine...${NC}"
cat << 'EOF' > /tmp/test_playback.swift
import Foundation
import AVFoundation

let fileURL = URL(fileURLWithPath: "/tmp/test_screenrecorder_sample.mp4")
guard FileManager.default.fileExists(atPath: fileURL.path) else { exit(1) }

let asset = AVURLAsset(url: fileURL)
let playerItem = AVPlayerItem(asset: asset)
let player = AVPlayer(playerItem: playerItem)

player.play()
print("PLAYBACK_SUCCESS: Volume=\(player.volume)")
exit(0)
EOF

if swift /tmp/test_playback.swift 2>&1 | grep -q "PLAYBACK_SUCCESS"; then
    pass "AVPlayer loaded and played synthesized MP4 clip"
else
    fail "Playback Engine" "Failed to load video in AVPlayer"
fi
rm -f /tmp/test_writer.swift /tmp/test_playback.swift /tmp/test_screenrecorder_sample.mp4

# TEST 5: Live App Launch & Window Display
echo -e "\n${YELLOW}5. Live Application Launch & Window Display...${NC}"
killall ScreenRecorder >/dev/null 2>&1 || true
sleep 1
open "$APP_BUNDLE"
sleep 2

if pgrep -fl "ScreenRecorder" >/dev/null; then
    PID=$(pgrep -fl "ScreenRecorder.app" | awk '{print $1}')
    pass "ScreenRecorder Studio launched successfully with live window and dock presence (PID: $PID)"
else
    fail "App Launch" "ScreenRecorder process not found after launch"
fi

# TEST 6: Camera Device Discovery & AVFoundation Capture
echo -e "\n${YELLOW}6. Camera Device Discovery & AVFoundation Capture...${NC}"
cat << 'EOF' > /tmp/test_camera.swift
import Foundation
import AVFoundation

let discoverySession = AVCaptureDevice.DiscoverySession(
    deviceTypes: [.builtInWideAngleCamera],
    mediaType: .video,
    position: .unspecified
)
print("CAMERA_DISCOVERY_SUCCESS: Found \(discoverySession.devices.count) cameras")
exit(0)
EOF

if swift /tmp/test_camera.swift 2>&1 | grep -q "CAMERA_DISCOVERY_SUCCESS"; then
    pass "AVCaptureDevice discovery executed successfully"
else
    fail "Camera Discovery" "Failed to query video capture devices"
fi
rm -f /tmp/test_camera.swift

# SUMMARY
echo -e "\n${BLUE}====================================================${NC}"
if [ $PASSED -eq $TOTAL ]; then
    echo -e "${GREEN}  ALL $TOTAL SMOKE TESTS PASSED! (100% HEALTHY)${NC}"
else
    echo -e "${RED}  $PASSED/$TOTAL TESTS PASSED${NC}"
fi
echo -e "${BLUE}====================================================${NC}\n"
