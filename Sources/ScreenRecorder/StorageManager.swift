import Foundation
import AVFoundation
import AppKit

public final class StorageManager {
    public static let shared = StorageManager()

    private let fileManager = FileManager.default
    public let recordingsDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ScreenRecorder/recordings", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.recordingsDirectory = dir
    }

    public func loadRecordings() -> [RecordingItem] {
        guard let files = try? fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles) else {
            return []
        }

        var items: [RecordingItem] = []

        for file in files where file.pathExtension.lowercased() == "mp4" || file.pathExtension.lowercased() == "mov" {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? Date()
            let size = Int64(values?.fileSize ?? 0)

            let asset = AVURLAsset(url: file)
            let durationSeconds = CMTimeGetSeconds(asset.duration)

            var w = 1920
            var h = 1080
            if let track = asset.tracks(withMediaType: .video).first {
                let s = track.naturalSize.applying(track.preferredTransform)
                w = Int(abs(s.width))
                h = Int(abs(s.height))
            }

            let hasAudio = !asset.tracks(withMediaType: .audio).isEmpty

            let item = RecordingItem(
                url: file,
                title: file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " "),
                date: date,
                duration: durationSeconds.isNaN ? 0 : durationSeconds,
                fileSizeBytes: size,
                width: w,
                height: h,
                hasSystemAudio: hasAudio,
                hasMicrophoneAudio: false
            )
            items.append(item)
        }

        return items.sorted { $0.date > $1.date }
    }

    public func deleteRecording(url: URL) {
        try? fileManager.removeItem(at: url)
    }

    public func generateThumbnail(for url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            return nil
        }
    }
}
