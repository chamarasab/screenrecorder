#!/bin/bash
set -e

echo "🛑 Quitting ScreenRecorder..."
killall ScreenRecorder 2>/dev/null || true
sleep 1

echo "🧹 Resetting macOS privacy permissions (TCC database)..."
tccutil reset ScreenCapture com.chamara.ScreenRecorder 2>/dev/null || true
tccutil reset Camera com.chamara.ScreenRecorder 2>/dev/null || true
tccutil reset Microphone com.chamara.ScreenRecorder 2>/dev/null || true

echo "🗑️ Removing /Applications/ScreenRecorder.app..."
rm -rf /Applications/ScreenRecorder.app
rm -rf ScreenRecorder.app

echo "✨ ScreenRecorder has been completely uninstalled and permissions reset."
