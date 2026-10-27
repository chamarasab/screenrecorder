import Foundation
import SwiftUI
@preconcurrency import AVFoundation
import AppKit

public enum CameraCircleSize: CGFloat, CaseIterable, Identifiable {
    case small = 160
    case medium = 220
    case large = 280

    public var id: CGFloat { rawValue }

    public var title: String {
        switch self {
        case .small: return "Small (160px)"
        case .medium: return "Medium (220px)"
        case .large: return "Large (280px)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
}

@MainActor
public final class CameraOverlayController: NSObject, ObservableObject {
    public static let shared = CameraOverlayController()

    @Published public var isVisible: Bool = false
    @Published public var circleSize: CameraCircleSize = .medium
    @Published public var isMirrored: Bool = true
    @Published public var availableCameras: [AVCaptureDevice] = []
    @Published public var selectedCameraID: String = ""

    private var captureSession: AVCaptureSession?
    public private(set) var window: NSPanel?

    public override init() {
        super.init()
        discoverCameras()
    }

    public func discoverCameras() {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.builtInWideAngleCamera, .external]
        } else {
            deviceTypes = [.builtInWideAngleCamera]
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        self.availableCameras = discoverySession.devices
        if let first = discoverySession.devices.first {
            self.selectedCameraID = first.uniqueID
        }
    }

    public func selectCamera(id: String) {
        self.selectedCameraID = id
        if isVisible {
            // Re-setup with new camera
            setupAndShowWindow()
        }
    }

    public func toggleOverlay() {
        if isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    public func showOverlay() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndShowWindow()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupAndShowWindow()
                    }
                }
            }
        default:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    public func hideOverlay() {
        if let session = captureSession {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
        captureSession = nil
        window?.close()
        window = nil
        isVisible = false
    }

    public func setSize(_ size: CameraCircleSize) {
        self.circleSize = size
        guard let win = window else { return }

        let currentFrame = win.frame
        let newOrigin = CGPoint(
            x: currentFrame.midX - size.rawValue / 2,
            y: currentFrame.midY - size.rawValue / 2
        )
        let newFrame = CGRect(origin: newOrigin, size: CGSize(width: size.rawValue, height: size.rawValue))
        win.setFrame(newFrame, display: true, animate: true)
    }

    private func setupAndShowWindow() {
        // Close any existing window/session
        if let session = captureSession {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
        window?.close()
        window = nil

        let session = AVCaptureSession()
        session.sessionPreset = .high

        let camera = availableCameras.first { $0.uniqueID == selectedCameraID } ?? AVCaptureDevice.default(for: .video)
        guard let camera = camera,
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let runningSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            runningSession.startRunning()
        }
        self.captureSession = session

        let size = circleSize.rawValue
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false

        let contentView = CameraCircleView(
            session: session,
            controller: self
        )
        panel.contentView = NSHostingView(rootView: contentView)

        // Default position in bottom-right corner of primary screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - size - 40
            let y = screenRect.minY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.window = panel
        self.isVisible = true
    }
}

// MARK: - Native Draggable View for Window Dragging
struct CameraCircleDragDetector: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableOverlayView {
        DraggableOverlayView()
    }
    func updateNSView(_ nsView: DraggableOverlayView, context: Context) {}
}

final class DraggableOverlayView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Circular Camera View with Drag & Hover Controls
struct CameraCircleView: View {
    let session: AVCaptureSession
    @ObservedObject var controller: CameraOverlayController
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Live Video Feed from Camera
            CameraPreviewLayerRepresentable(session: session)
                .clipShape(Circle())
                .scaleEffect(x: controller.isMirrored ? -1 : 1, y: 1)

            // Transparent overlay that captures dragging anywhere on the circle
            CameraCircleDragDetector()
                .clipShape(Circle())

            // Outer glowing border
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.cyan, .blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3.5
                )

            // Hover Controls Overlay (Top: Close & Mirror, Bottom: Size Picker)
            if isHovering {
                VStack {
                    HStack {
                        // Mirror Toggle Button
                        Button(action: {
                            withAnimation {
                                controller.isMirrored.toggle()
                            }
                        }) {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Flip / Mirror Camera")
                        .padding(.leading, 12)
                        .padding(.top, 12)

                        Spacer()

                        // Close Button
                        Button(action: {
                            controller.hideOverlay()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .buttonStyle(.plain)
                        .help("Close Camera Overlay")
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                    }

                    Spacer()

                    // Drag hint & Quick Size Selector
                    VStack(spacing: 4) {
                        HStack(spacing: 3) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 8))
                            Text("Drag to move")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 8) {
                            ForEach(CameraCircleSize.allCases) { s in
                                Button(s.shortLabel) {
                                    controller.setSize(s)
                                }
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(controller.circleSize == s ? Color.blue : Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(18)
                    .padding(.bottom, 12)
                }
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct CameraPreviewLayerRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.wantsLayer = true
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.frame = nsView.bounds
    }
}
