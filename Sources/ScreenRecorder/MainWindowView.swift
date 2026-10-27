import SwiftUI

public struct MainWindowView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Header & Brand
                sidebarHeader
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

                Divider()

                // Permission Warning (if needed)
                if !appState.hasPermission {
                    permissionBanner
                        .padding(10)
                    Divider()
                }

                // Control Card (Recording, Audio, & Camera)
                recordingControlCard
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

                Divider()

                // Recordings List / Gallery
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("RECORDINGS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appState.recordings.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    if appState.recordings.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "video.slash")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No recordings yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List(selection: $appState.selectedRecording) {
                            ForEach(appState.recordings) { item in
                                RecordingRow(item: item, isSelected: appState.selectedRecording?.id == item.id)
                                    .tag(item)
                            }
                        }
                        .listStyle(.sidebar)
                    }
                }

                Divider()

                // Footer
                HStack {
                    Text("Auto-saves with System Audio")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        appState.refreshRecordings()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh recordings list")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
        } detail: {
            if let recording = appState.selectedRecording {
                VideoPlayerView(
                    recording: recording,
                    onDelete: {
                        appState.deleteRecording(recording)
                    }
                )
            } else {
                emptyDetailState
            }
        }
    }

    private var sidebarHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)

                Text("ScreenRecorder")
                    .font(.system(size: 15, weight: .bold))
            }

            Spacer()

            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("M5 Metal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Screen Permission Required")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Text("macOS requires permission to capture your screen and system audio.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button("Grant Permission in Settings") {
                    appState.openScreenRecordingSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Refresh") {
                    appState.checkAndRefreshPermissions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
    }

    private var recordingControlCard: some View {
        VStack(spacing: 10) {
            switch appState.state {
            case .recording(let elapsed):
                VStack(spacing: 10) {
                    HStack {
                        PulsingRecordingDot()
                        Text("RECORDING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                        Text(formatDuration(elapsed))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                    }

                    Button(action: {
                        appState.stopRecording()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop & Save Recording")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    // Facecam controls accessible during recording too!
                    facecamControlCard
                }

            case .finalizing:
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving high-resolution MP4 video...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)

            case .error(let msg):
                VStack(alignment: .leading, spacing: 4) {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Dismiss") {
                        appState.state = .idle
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

            case .idle:
                VStack(spacing: 10) {
                    // Start Recording Trigger
                    Button(action: {
                        appState.startRecording()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                            Text("Start Recording Screen")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)

                    // Audio Toggles
                    VStack(spacing: 6) {
                        Toggle(isOn: $appState.settings.captureSystemAudio) {
                            HStack(spacing: 6) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 16)
                                Text("System Audio (Mac Sound)")
                                    .font(.caption)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle(isOn: $appState.settings.captureMicrophone) {
                            HStack(spacing: 6) {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 16)
                                Text("Microphone Voiceover")
                                    .font(.caption)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                    .cornerRadius(6)

                    // Camera Facecam Controls (Draggable & Resizable)
                    facecamControlCard

                    // Quality & Display Pickers
                    HStack(spacing: 8) {
                        Picker("FPS", selection: $appState.settings.fps) {
                            Text("30 FPS").tag(30)
                            Text("60 FPS").tag(60)
                        }
                        .pickerStyle(.menu)
                        .font(.caption)

                        Picker("Quality", selection: $appState.settings.resolutionPreset) {
                            ForEach(ResolutionPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                    }
                }
            }
        }
    }

    private var facecamControlCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Toggle(isOn: Binding(
                    get: { appState.camera.isVisible },
                    set: { enabled in
                        if enabled {
                            appState.camera.showOverlay()
                        } else {
                            appState.camera.hideOverlay()
                        }
                    }
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.circle.fill")
                            .foregroundColor(.purple)
                            .frame(width: 16)
                        Text("Webcam Facecam Circle")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .toggleStyle(.checkbox)

                Spacer()

                if appState.camera.isVisible {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }

            // Size Selector (Small / Medium / Large)
            HStack(spacing: 6) {
                Text("Circle Size:")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)

                ForEach(CameraCircleSize.allCases) { size in
                    Button(action: {
                        appState.camera.setSize(size)
                    }) {
                        Text(size.shortLabel)
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 26, height: 20)
                            .background(appState.camera.circleSize == size ? Color.purple.opacity(0.3) : Color.clear)
                            .foregroundColor(appState.camera.circleSize == size ? .purple : .primary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(appState.camera.circleSize == size ? Color.purple : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(size.title)
                }

                Spacer()

                if appState.camera.isVisible {
                    Button(action: {
                        withAnimation {
                            appState.camera.isMirrored.toggle()
                        }
                    }) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Flip Camera Horizontally")
                }
            }

            // Camera selector if multiple cameras exist
            if appState.camera.availableCameras.count > 1 {
                Picker("Camera", selection: Binding(
                    get: { appState.camera.selectedCameraID },
                    set: { appState.camera.selectCamera(id: $0) }
                )) {
                    ForEach(appState.camera.availableCameras, id: \.uniqueID) { dev in
                        Text(dev.localizedName).tag(dev.uniqueID)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption2)
            }

            Text("Draggable circle • Captured directly into screen recording")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(8)
        .background(Color(NSColor.textBackgroundColor).opacity(0.4))
        .cornerRadius(6)
    }

    private var emptyDetailState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.waveform")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.7))

            Text("ScreenRecorder Studio")
                .font(.title)
                .fontWeight(.bold)

            Text("Record crisp screen videos with internal macOS audio and floating webcam circle. QuickTime cannot capture computer sound, but ScreenRecorder does natively.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 440)

            HStack(spacing: 16) {
                Label("60 FPS H.264", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Internal Audio", systemImage: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Label("Facecam Overlay", systemImage: "camera.circle.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                Label("Built-in Player", systemImage: "play.circle.fill")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Subviews
struct RecordingRow: View {
    let item: RecordingItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 44, height: 32)

                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(item.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct PulsingRecordingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.25 : 0.9)
            .opacity(isPulsing ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}
