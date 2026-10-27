import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                    Text("ScreenRecorder")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("System Audio")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)

            Divider()

            // Recording Action
            VStack(spacing: 10) {
                switch appState.state {
                case .recording(let elapsed):
                    VStack(spacing: 8) {
                        HStack {
                            PulsingRecordingDot()
                            Text("RECORDING SCREEN")
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
                                Text("Stop Recording")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                case .finalizing:
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Finalizing MP4 video...")
                            .font(.caption)
                    }
                    .padding(.vertical, 6)

                case .error(let msg):
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Dismiss") {
                        appState.state = .idle
                    }

                case .idle:
                    VStack(spacing: 8) {
                        Button(action: {
                            appState.startRecording()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "record.circle")
                                    .foregroundColor(.red)
                                Text("Start Recording Screen")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)

                        HStack {
                            Toggle("Audio", isOn: $appState.settings.captureSystemAudio)
                                .toggleStyle(.checkbox)
                                .font(.caption2)
                            Spacer()
                            Toggle("Mic", isOn: $appState.settings.captureMicrophone)
                                .toggleStyle(.checkbox)
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding(12)

            Divider()

            // Quick Gallery Snippet
            if !appState.recordings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT RECORDINGS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)

                    ForEach(appState.recordings.prefix(3)) { item in
                        Button(action: {
                            appState.selectedRecording = item
                            NSApp.activate(ignoringOtherApps: true)
                        }) {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.accentColor)
                                Text(item.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.formattedDuration)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Divider()
            }

            // Bottom Toolbar
            HStack {
                Button("Open Studio Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 300)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
