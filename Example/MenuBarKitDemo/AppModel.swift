import Combine
import MenuBarKit
import SwiftUI

/// Everything the demo app shares between its menu bar panel, its settings and the screenshots.
@MainActor
final class AppModel {
    static let shared = AppModel()

    let timer: FocusTimer
    let toggleShortcut: GlobalShortcut
    let resetShortcut: GlobalShortcut
    let updates: UpdateChecker

    private init() {
        let timer = FocusTimer()
        self.timer = timer
        // Global shortcuts work while any app is in front.
        toggleShortcut = GlobalShortcut("toggleTimer", default: KeyShortcut("⌥⌘T")) {
            timer.toggle()
        }
        resetShortcut = GlobalShortcut("resetTimer", default: KeyShortcut("⌃⌥⌘R")) {
            timer.reset()
        }
        updates = UpdateChecker(
            feedURL: DemoContent.feedURL,
            loader: StaticFeedLoader(json: DemoContent.feedJSON)
        )
    }

    func checkForUpdates() {
        Task { await updates.checkForUpdates() }
    }
}
