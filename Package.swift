// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ScreenRecorder",
            targets: ["ScreenRecorder"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ScreenRecorder",
            dependencies: [],
            path: "Sources/ScreenRecorder"
        )
    ]
)
