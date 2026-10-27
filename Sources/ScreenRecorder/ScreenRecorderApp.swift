import SwiftUI
import AppKit

@main
struct ScreenRecorderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("ScreenRecorder Studio") {
            MainWindowView(appState: appState)
                .frame(minWidth: 820, idealWidth: 980, minHeight: 540, idealHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            statusItemLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var statusItemLabel: some View {
        switch appState.state {
        case .recording(let elapsed):
            HStack(spacing: 4) {
                Image(systemName: "record.circle.fill")
                    .foregroundColor(.red)
                let mins = Int(elapsed) / 60
                let secs = Int(elapsed) % 60
                Text(String(format: "%02d:%02d", mins, secs))
                    .monospacedDigit()
                    .font(.system(size: 11, weight: .bold))
            }
        case .finalizing:
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                Text("Saving...")
                    .font(.system(size: 11))
            }
        default:
            Image(systemName: "record.circle")
        }
    }
}
