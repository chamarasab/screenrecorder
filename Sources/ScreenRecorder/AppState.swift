import Foundation
import SwiftUI
import ScreenCaptureKit
import Combine
import AppKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var state: RecorderState = .idle
    @Published public var recordings: [RecordingItem] = []
    @Published public var selectedRecording: RecordingItem? = nil
    @Published public var settings: RecordingSettings = RecordingSettings()
    @Published public var availableDisplays: [String] = ["Primary Display"]
    @Published public var selectedDisplayIndex: Int = 0
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var hasPermission: Bool = false

    public let camera = CameraOverlayController.shared

    private let engine = ScreenRecorderEngine.shared
    private let storage = StorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var permissionPollTimer: Timer?

    public init() {
        self.recordings = storage.loadRecordings()
        self.selectedRecording = recordings.first
        self.hasPermission = engine.checkPermissions()

        engine.$elapsedTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elapsed in
                self?.recordingDuration = elapsed
                if case .recording = self?.state {
                    self?.state = .recording(elapsed: elapsed)
                }
            }
            .store(in: &cancellables)

        // Observe when app becomes active to check permissions
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndRefreshPermissions()
            }
            .store(in: &cancellables)

        // Initial check with ScreenCaptureKit
        fetchDisplays(force: true)
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        // SILENT POLLING: uses non-intrusive preflight check
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.engine.checkPermissions() {
                    self.hasPermission = true
                    timer.invalidate()
                    self.permissionPollTimer = nil
                    self.fetchDisplays(force: true)
                }
            }
        }
    }

    public func checkAndRefreshPermissions() {
        if engine.checkPermissions() {
            self.hasPermission = true
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
            fetchDisplays(force: true)
        } else {
            // Also directly verify via ScreenCaptureKit in case CGPreflight has an ad-hoc disparity on macOS Sequoia
            fetchDisplays(force: true)
        }
    }

    public func fetchDisplays(force: Bool = false) {
        Task {
            do {
                let content = try await SCShareableContent.current
                await MainActor.run {
                    self.hasPermission = true
                    self.permissionPollTimer?.invalidate()
                    self.permissionPollTimer = nil
                    self.availableDisplays = content.displays.enumerated().map { index, display in
                        "Display \(index + 1) (\(display.width)x\(display.height))"
                    }
                    if self.availableDisplays.isEmpty {
                        self.availableDisplays = ["Primary Display"]
                    }
                }
            } catch {
                await MainActor.run {
                    self.hasPermission = false
                }
            }
        }
    }

    public func openScreenRecordingSettings() {
        // Trigger OS permission registration once if not yet granted
        if !engine.checkPermissions() {
            engine.requestPermissions()
        }

        // Open System Settings directly to Screen & System Audio Recording
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }

        startPermissionPolling()
    }

    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundleURL.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    public func requestPermissions() {
        openScreenRecordingSettings()
    }

    public func toggleRecording() {
        if engine.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    public func startRecording() {
        guard !engine.isRecording else { return }

        Task {
            do {
                _ = try await engine.startRecording(
                    settings: settings,
                    displayIndex: selectedDisplayIndex
                )
                await MainActor.run {
                    self.state = .recording(elapsed: 0)
                    self.hasPermission = true
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Failed to start screen capture: \(error.localizedDescription)")
                    self.checkAndRefreshPermissions()
                }
            }
        }
    }

    public func stopRecording() {
        guard engine.isRecording else { return }

        self.state = .finalizing

        Task {
            do {
                if let outputURL = try await engine.stopRecording() {
                    // Small delay to ensure writer flushes metadata
                    try? await Task.sleep(nanoseconds: 500_000_000)

                    await MainActor.run {
                        self.refreshRecordings()
                        self.selectedRecording = self.recordings.first { $0.url == outputURL } ?? self.recordings.first
                        self.state = .idle
                    }
                } else {
                    await MainActor.run {
                        self.state = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Failed to finalize video recording: \(error.localizedDescription)")
                }
            }
        }
    }

    public func deleteRecording(_ item: RecordingItem) {
        storage.deleteRecording(url: item.url)
        recordings.removeAll { $0.id == item.id }
        if selectedRecording?.id == item.id {
            selectedRecording = recordings.first
        }
    }

    public func refreshRecordings() {
        self.recordings = storage.loadRecordings()
    }
}
