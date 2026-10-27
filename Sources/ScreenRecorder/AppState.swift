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

        // Observe when app becomes active to immediately refresh permissions
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndRefreshPermissions()
            }
            .store(in: &cancellables)

        fetchDisplays()
        startPermissionPolling()
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.hasPermission {
                    self.checkAndRefreshPermissions()
                }
            }
        }
    }

    public func checkAndRefreshPermissions() {
        let granted = engine.checkPermissions()
        if granted != self.hasPermission {
            self.hasPermission = granted
        }
        fetchDisplays()
    }

    public func fetchDisplays() {
        Task {
            do {
                let content = try await SCShareableContent.current
                await MainActor.run {
                    self.hasPermission = true
                    self.availableDisplays = content.displays.enumerated().map { index, display in
                        "Display \(index + 1) (\(display.width)x\(display.height))"
                    }
                    if self.availableDisplays.isEmpty {
                        self.availableDisplays = ["Primary Display"]
                    }
                }
            } catch {
                await MainActor.run {
                    let preflight = self.engine.checkPermissions()
                    self.hasPermission = preflight
                }
            }
        }
    }

    public func openScreenRecordingSettings() {
        // Trigger OS permission prompt dialog if not determined yet
        engine.requestPermissions()

        // Directly open System Settings -> Screen & System Audio Recording
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }

        // Check again after a brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAndRefreshPermissions()
        }
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
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Failed to start screen capture: \(error.localizedDescription)")
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
