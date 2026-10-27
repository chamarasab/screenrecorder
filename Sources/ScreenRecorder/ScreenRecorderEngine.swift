import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

public final class ScreenRecorderEngine: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public static let shared = ScreenRecorderEngine()

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var elapsedTime: TimeInterval = 0
    @Published public private(set) var currentAudioLevel: Float = 0.0

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var recordingStartTime: Date?
    private var timer: Timer?
    private var sessionStarted = false
    private var outputURL: URL?

    private let writerQueue = DispatchQueue(label: "com.screenrecorder.writerQueue", qos: .userInitiated)

    public override init() {
        super.init()
    }

    public func checkPermissions() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    public func requestPermissions() {
        CGRequestScreenCaptureAccess()
    }

    public func startRecording(
        settings: RecordingSettings,
        displayIndex: Int = 0
    ) async throws -> URL {
        guard !isRecording else {
            throw NSError(domain: "ScreenRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Already recording"])
        }

        // 1. Fetch available screen content
        let content = try await SCShareableContent.current
        guard !content.displays.isEmpty else {
            throw NSError(domain: "ScreenRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "No display detected"])
        }

        let targetDisplay = displayIndex < content.displays.count ? content.displays[displayIndex] : content.displays[0]

        // 2. Setup Storage Destination
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recordingsDir = appSupport.appendingPathComponent("ScreenRecorder/recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: recordingsDir.path) {
            try? fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileURL = recordingsDir.appendingPathComponent("Recording_\(timestamp).mp4")
        self.outputURL = fileURL

        // Remove old file if needed
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }

        // 3. Configure AVAssetWriter
        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        self.assetWriter = writer

        // Determine dimensions
        let rawWidth = targetDisplay.width
        let rawHeight = targetDisplay.height
        let targetSize = settings.resolutionPreset.targetSize(for: CGSize(width: rawWidth, height: rawHeight))
        let width = Int(targetSize.width) & ~1 // Ensure even numbers for H.264
        let height = Int(targetSize.height) & ~1

        // Video Settings (Hardware H.264)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000, // 10 Mbps for crisp clarity
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: settings.fps
            ]
        ]

        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        self.videoInput = vInput

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        if writer.canAdd(vInput) {
            writer.add(vInput)
        }

        // Audio Settings (System Audio & Mic via AAC)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192000
        ]

        if settings.captureSystemAudio {
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            self.audioInput = aInput
            if writer.canAdd(aInput) {
                writer.add(aInput)
            }
        }

        if settings.captureMicrophone {
            let mInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            mInput.expectsMediaDataInRealTime = true
            self.micInput = mInput
            if writer.canAdd(mInput) {
                writer.add(mInput)
            }
        }

        guard writer.startWriting() else {
            throw NSError(
                domain: "ScreenRecorder",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize video writer: \(writer.error?.localizedDescription ?? "Unknown error")"]
            )
        }

        self.sessionStarted = false

        // 4. Configure ScreenCaptureKit Stream
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.fps))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = settings.captureCursor

        // System Audio Capture (The secret weapon!)
        config.capturesAudio = settings.captureSystemAudio
        config.excludesCurrentProcessAudio = true

        #if os(macOS)
        if #available(macOS 15.0, *) {
            config.captureMicrophone = settings.captureMicrophone
        }
        #endif

        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: writerQueue)

        if settings.captureSystemAudio {
            try scStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: writerQueue)
        }

        #if os(macOS)
        if #available(macOS 15.0, *) {
            if settings.captureMicrophone {
                try scStream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: writerQueue)
            }
        }
        #endif

        self.stream = scStream
        try await scStream.startCapture()

        await MainActor.run {
            self.isRecording = true
            self.elapsedTime = 0
            self.recordingStartTime = Date()

            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.recordingStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }

        return fileURL
    }

    public func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }

        await MainActor.run {
            self.timer?.invalidate()
            self.timer = nil
            self.isRecording = false
        }

        // Stop stream capture
        if let s = stream {
            try? await s.stopCapture()
            self.stream = nil
        }

        // Finalize video asset writing
        return try await withCheckedThrowingContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self = self, let writer = self.assetWriter else {
                    continuation.resume(returning: nil)
                    return
                }

                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                self.micInput?.markAsFinished()

                writer.finishWriting {
                    if writer.status == .completed {
                        continuation.resume(returning: self.outputURL)
                    } else if let err = writer.error {
                        continuation.resume(throwing: err)
                    } else {
                        continuation.resume(returning: self.outputURL)
                    }
                    self.assetWriter = nil
                    self.videoInput = nil
                    self.audioInput = nil
                    self.micInput = nil
                    self.pixelBufferAdaptor = nil
                    self.sessionStarted = false
                }
            }
        }
    }

    // MARK: - SCStreamOutput Callback
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        writerQueue.async { [weak self] in
            guard let self = self, let writer = self.assetWriter, writer.status == .writing else { return }

            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            if !self.sessionStarted {
                writer.startSession(atSourceTime: pts)
                self.sessionStarted = true
            }

            switch outputType {
            case .screen:
                guard let vInput = self.videoInput, vInput.isReadyForMoreMediaData else { return }
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                   let adaptor = self.pixelBufferAdaptor {
                    adaptor.append(imageBuffer, withPresentationTime: pts)
                }

            case .audio:
                guard let aInput = self.audioInput, aInput.isReadyForMoreMediaData else { return }
                aInput.append(sampleBuffer)

            default:
                #if os(macOS)
                if #available(macOS 15.0, *) {
                    if outputType == .microphone {
                        guard let mInput = self.micInput, mInput.isReadyForMoreMediaData else { return }
                        mInput.append(sampleBuffer)
                    }
                }
                #endif
            }
        }
    }

    // MARK: - SCStreamDelegate
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("SCStream stopped with error: \(error.localizedDescription)")
    }
}
