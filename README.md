# ScreenRecorder Studio 🎥
> **Production-Grade Screen & Internal System Audio Recorder for macOS**  
> *Native Apple ScreenCaptureKit • Internal Mac Audio Capture • Hardware H.264 Encoding • In-App Video Player*

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20%7C%20Sonoma%20%7C%20Sequoia-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=for-the-badge&logo=swift)](https://swift.org)
[![ScreenCaptureKit](https://img.shields.io/badge/ScreenCaptureKit-Native%20System%20Audio-red?style=for-the-badge)](https://developer.apple.com/documentation/screencapturekit)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## 📖 Table of Contents
1. [The Problem with QuickTime](#-the-problem-with-quicktime)
2. [Key Features](#-key-features)
3. [Architecture](#-architecture)
4. [User Manual](#-user-manual)
   - [1. Installation & Building](#1-installation--building)
   - [2. Granting Permissions](#2-granting-permissions)
   - [3. Configuring System Audio & Microphone](#3-configuring-system-audio--microphone)
   - [4. Recording Your Screen](#4-recording-your-screen)
   - [5. Playing Back Videos In-App](#5-playing-back-videos-in-app)
   - [6. Managing & Exporting Files](#6-managing--exporting-files)
5. [Dual-Mode Interface (Studio vs. Menu Bar)](#-dual-mode-interface)
6. [Developer & Testing Guide](#-developer--testing-guide)
7. [License](#-license)

---

## 💡 The Problem with QuickTime

By default, Apple's built-in **QuickTime Player cannot capture internal computer audio**. When you record a browser video, a meeting, a tutorial, or a game with QuickTime:
* ❌ QuickTime only records the built-in microphone (picking up fan noise and room echoes).
* ❌ Workarounds require installing third-party virtual audio loopback drivers (like BlackHole or Soundflower), which often break audio routing, introduce latency, or crash system preferences.

**ScreenRecorder Studio** solves this completely by leveraging Apple's modern **ScreenCaptureKit** framework:
* ✅ **Direct System Audio:** Intercepts and encodes the Mac's internal audio track directly into the video container without installing any virtual drivers.
* ✅ **Hardware H.264 & AAC Encoding:** VideoToolbox hardware acceleration ensures 60 FPS recording with zero CPU stutters.
* ✅ **Built-In Video Player:** Preview, scrub, speed-up, and listen to your recordings immediately inside the app (just like Movavi Screen Recorder).

---

## ⚡ Key Features

| Feature | Description |
| :--- | :--- |
| **🔊 Internal System Audio** | Captures music, video audio, game sound, and meeting voices playing on your Mac. |
| **🎙️ Microphone Voiceover** | Optional voiceover track mixed with internal audio for tutorials and demos. |
| **⚡ 60 FPS Hardware Encoding** | Smooth 60 FPS or 30 FPS MP4 capture powered by Apple Silicon VideoToolbox. |
| **🎬 In-App Video Player** | Play, pause, scrub timeline, adjust volume, and change playback speed (0.5x to 2x). |
| **🗂️ Built-in Video Gallery** | Browse past recordings with duration, file size, and audio badges. |
| **🪟 Dual-Mode UI** | Full Studio Window + sleek Menu Bar companion for quick access. |

---

## 🏗️ Architecture

```
┌────────────────────────────────────────┐
│     macOS Display (ScreenCaptureKit)   │
└───────────────────┬────────────────────┘
                    │ 60 FPS BGRA Video Frame Buffers
                    ▼
┌────────────────────────────────────────┐
│  Internal Audio Stream (SCStreamAudio) │  <── Computer Sound (Zero Loopback Drivers)
└───────────────────┬────────────────────┘
                    │ PCM Audio Buffers (48kHz Stereo)
                    ▼
┌────────────────────────────────────────┐
│    AVAssetWriter (VideoToolbox GPU)    │  <── Hardware H.264 + AAC MP4 Muxer
└───────────────────┬────────────────────┘
                    │ High-Resolution .MP4
                    ▼
┌────────────────────────────────────────┐
│     In-App Video Player & Gallery      │  <── Custom AVPlayer with Timeline Scrubber
└────────────────────────────────────────┘
```

---

## 📘 User Manual

### 1. Installation & Building
1. Clone the repository:
   ```bash
   git clone https://github.com/chamarasab/screenrecorder.git
   cd screenrecorder
   ```
2. Run the packaging script:
   ```bash
   ./bundle.sh
   ```
   *This compiles the app with release optimizations, embeds the custom icon, and applies ad-hoc codesigning.*
3. Launch the app:
   ```bash
   open ScreenRecorder.app
   ```

### 2. Granting Permissions
1. On first launch, macOS will request **Screen Recording** permission.
2. Go to **System Settings > Privacy & Security > Screen & System Audio Recording**, and toggle **ScreenRecorder** to ON.
3. Relaunch the app.

---

### 3. Configuring System Audio & Microphone
In the left sidebar of ScreenRecorder Studio:
* **System Audio (Mac Sound):** Check this to capture internal computer audio (YouTube, Zoom, Spotify, Games).
* **Microphone Voiceover:** Check this if you want to record your microphone simultaneously for tutorials or presentations.
* **FPS:** Choose **60 FPS** for ultra-smooth video or **30 FPS** for smaller file sizes.
* **Quality:** Choose **Native Retina** for pixel-perfect resolution, or **1080p Full HD**.

---

### 4. Recording Your Screen
1. Click **"Start Recording Screen"** (in the Studio Window or from the Menu Bar).
2. The recording indicator will glow red with an active timer.
3. Perform your tasks, play your video, or conduct your presentation.
4. Click **"Stop & Save Recording"**.
5. The MP4 video is finalized within milliseconds and automatically selected in your library.

---

### 5. Playing Back Videos In-App
Unlike QuickTime where you have to hunt for saved files:
* Select any recording from the left sidebar gallery.
* The video loads directly into the **In-App Player**.
* **Controls:**
  * **Play / Pause:** Spacebar or click the center button.
  * **Scrubber Slider:** Drag along the timeline to jump to any frame.
  * **Speed Selector:** Toggle between `0.5x`, `1.0x`, `1.25x`, `1.5x`, and `2.0x`.
  * **Volume:** Adjust playback volume or mute sound.

---

### 6. Managing & Exporting Files
* **Reveal in Finder:** Click the **Finder** button to highlight the `.mp4` file in macOS Finder.
* **QuickTime / External Player:** Click **QuickTime** to open in an external video editor.
* **Delete:** Click the **Trash** icon to remove unwanted recordings and free up disk space.

---

## 🖥️ Dual-Mode Interface

* **Studio Dashboard:** Comprehensive video editor interface with playback canvas, audio controls, and recording history.
* **Menu Bar Companion:** Sits in the top-right status bar (`record.circle`) so you can trigger screen recording while playing full-screen games or presenting without bringing up the main window.

---

## 🛠️ Developer & Testing Guide

### Building the Release Bundle
```bash
./bundle.sh
```

### Running Automated Smoke Tests
To verify Mach-O integrity, ScreenCaptureKit API, AVAssetWriter MP4 synthesis, in-app AVPlayer loading, and live launch:
```bash
./smoke_test.sh
```

---

## 📄 License

ScreenRecorder Studio is open-source software licensed under the [MIT License](LICENSE).
