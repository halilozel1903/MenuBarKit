import MenuBarKit
import SwiftUI

@main
struct MenuBarKitDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var timer = AppModel.shared.timer

    var body: some Scene {
        // The menu bar item: a timer symbol, plus the time left while a session runs.
        MenuBarApp("Tempo", systemImage: "timer", statusTitle: timer.menuBarTitle) {
            TempoPanel(model: .shared)
        }

        Settings {
            TempoSettings(model: .shared)
        }
    }
}

/// Starts the update check at launch, and shows a screenshot scene when CI asks for one.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var screenshot: ScreenshotWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let scene = ScreenshotScene.current {
            // Screenshot scenes show one screen in a normal window and never check for updates.
            screenshot = ScreenshotWindow(scene: scene, renderPath: ScreenshotScene.renderPath)
            return
        }
        AppModel.shared.checkForUpdates()
    }
}
