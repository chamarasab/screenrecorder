import Foundation
import CoreGraphics
import AppKit

public enum ResolutionPreset: String, CaseIterable, Identifiable, Codable {
    case native = "Native Retina"
    case fhd1080p = "1080p Full HD"
    case hd720p = "720p HD"

    public var id: String { rawValue }

    public func targetSize(for displaySize: CGSize) -> CGSize {
        switch self {
        case .native:
            return displaySize
        case .fhd1080p:
            let aspect = displaySize.width / displaySize.height
            return CGSize(width: 1920, height: 1920 / aspect)
        case .hd720p:
            let aspect = displaySize.width / displaySize.height
            return CGSize(width: 1280, height: 1280 / aspect)
        }
    }
}

public struct RecordingSettings: Equatable {
    public var captureSystemAudio: Bool = true
    public var captureMicrophone: Bool = false
    public var captureCursor: Bool = true
    public var fps: Int = 60
    public var resolutionPreset: ResolutionPreset = .native

    public init(
        captureSystemAudio: Bool = true,
        captureMicrophone: Bool = false,
        captureCursor: Bool = true,
        fps: Int = 60,
        resolutionPreset: ResolutionPreset = .native
    ) {
        self.captureSystemAudio = captureSystemAudio
        self.captureMicrophone = captureMicrophone
        self.captureCursor = captureCursor
        self.fps = fps
        self.resolutionPreset = resolutionPreset
    }
}

public struct RecordingItem: Identifiable, Equatable, Hashable {
    public var id: UUID
    public var url: URL
    public var title: String
    public var date: Date
    public var duration: TimeInterval
    public var fileSizeBytes: Int64
    public var width: Int
    public var height: Int
    public var hasSystemAudio: Bool
    public var hasMicrophoneAudio: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        date: Date = Date(),
        duration: TimeInterval = 0,
        fileSizeBytes: Int64 = 0,
        width: Int = 1920,
        height: Int = 1080,
        hasSystemAudio: Bool = true,
        hasMicrophoneAudio: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.date = date
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.width = width
        self.height = height
        self.hasSystemAudio = hasSystemAudio
        self.hasMicrophoneAudio = hasMicrophoneAudio
    }

    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }

    public var formattedSize: String {
        return formattedFileSize
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public enum RecorderState: Equatable {
    case idle
    case recording(elapsed: TimeInterval)
    case finalizing
    case error(String)
}
