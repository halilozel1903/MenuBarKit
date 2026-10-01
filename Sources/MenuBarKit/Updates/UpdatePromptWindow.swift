import AppKit
import SwiftUI

/// Shows an ``UpdatePromptView`` in its own small window, wired to an ``UpdateChecker``.
///
/// Menu bar apps have no main window to attach a sheet to, so the prompt gets a window of its
/// own. The app is activated so the window comes to the front.
///
/// ```swift
/// if let release = updates.availableRelease {
///     UpdatePromptWindow.show(release, checker: updates)
/// }
/// ```
@MainActor
public enum UpdatePromptWindow {
    private static var window: NSWindow?

    /// Opens the prompt, or brings it to the front with the new release when it is already open.
    public static func show(_ release: UpdateRelease, checker: UpdateChecker, appName: String = AboutInfo.fromBundle().appName) {
        let prompt = UpdatePromptView(
            release: release,
            currentVersion: checker.currentVersion,
            appName: appName,
            onDownload: {
                checker.download(release)
                close()
            },
            onSkip: {
                checker.skip(release)
                close()
            },
            onRemindLater: {
                checker.remindLater(release)
                close()
            }
        )

        let promptWindow = Self.window ?? makeWindow()
        promptWindow.contentViewController = NSHostingController(rootView: prompt)
        promptWindow.title = String(localized: "Software Update")
        Self.window = promptWindow
        promptWindow.center()
        NSApplication.shared.activate()
        promptWindow.makeKeyAndOrderFront(nil)
    }

    /// Closes the prompt if it is open.
    public static func close() {
        Self.window?.close()
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }
}
