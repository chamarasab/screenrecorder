import SwiftUI
import AVKit
import AppKit

public struct VideoPlayerView: View {
    let recording: RecordingItem
    let onDelete: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var timeObserver: Any?
    @State private var playbackRate: Float = 1.0
    @State private var volume: Float = 1.0

    private let playbackRates: [Float] = [0.5, 1.0, 1.25, 1.5, 2.0]

    public var body: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.title)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Label("\(recording.width)x\(recording.height)", systemImage: "display")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•").foregroundColor(.secondary)

                        Label(recording.formattedDuration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•").foregroundColor(.secondary)

                        Label(recording.formattedFileSize, systemImage: "internaldrive")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if recording.hasSystemAudio {
                            Text("•").foregroundColor(.secondary)
                            Label("System Audio", systemImage: "speaker.wave.2.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    Button(action: revealInFinder) {
                        Label("Finder", systemImage: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: openInDefaultApp) {
                        Label("QuickTime", systemImage: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete recording")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Video Canvas
            ZStack {
                if let p = player {
                    CustomAVPlayerView(player: p)
                        .background(Color.black)
                } else {
                    Color.black
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Custom Video Controls Bar
            HStack(spacing: 12) {
                // Play / Pause Button
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Current Time
                Text(formatTime(currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                // Timeline Scrubber Slider
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { newTime in
                            seek(to: newTime)
                        }
                    ),
                    in: 0...max(duration, 0.1)
                )
                .controlSize(.small)

                // Total Duration
                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                Divider().frame(height: 16)

                // Playback Speed Menu
                Menu {
                    ForEach(playbackRates, id: \.self) { rate in
                        Button("\(String(format: "%.2fx", rate))") {
                            setRate(rate)
                        }
                    }
                } label: {
                    Text("\(String(format: "%.2fx", playbackRate))")
                        .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 50)

                // Volume Icon
                Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Slider(value: $volume, in: 0...1) { _ in
                    player?.volume = volume
                }
                .frame(width: 60)
                .controlSize(.mini)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .onChange(of: recording.url) {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        teardownPlayer()

        guard FileManager.default.fileExists(atPath: recording.url.path) else { return }

        let p = AVPlayer(url: recording.url)
        p.volume = volume
        self.player = p

        // Load duration
        Task {
            if let asset = p.currentItem?.asset {
                let dur = try? await asset.load(.duration)
                if let d = dur {
                    await MainActor.run {
                        self.duration = CMTimeGetSeconds(d)
                    }
                }
            }
        }

        // Add periodic time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = CMTimeGetSeconds(time)
            if let d = self.player?.currentItem?.duration {
                let sec = CMTimeGetSeconds(d)
                if !sec.isNaN && sec > 0 {
                    self.duration = sec
                }
            }
        }

        // Listen for finish
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            self.isPlaying = false
            self.currentTime = 0
            p.seek(to: .zero)
        }
    }

    private func teardownPlayer() {
        if let observer = timeObserver, let p = player {
            p.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.rate = playbackRate
            p.play()
            isPlaying = true
        }
    }

    private func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(recording.url.path, inFileViewerRootedAtPath: "")
    }

    private func openInDefaultApp() {
        NSWorkspace.shared.open(recording.url)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "00:00" }
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// AppKit AVPlayerView wrapper for optimal performance
struct CustomAVPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = true
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
