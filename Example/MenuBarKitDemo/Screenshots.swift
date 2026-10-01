import AppKit
import MenuBarKit
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
///
/// Launch with `-screenshot <scene>` to show one scene in a regular window of a fixed size, because a
/// real menu bar window cannot be opened reliably on a CI runner. Add `-render-screenshot <file.png>`
/// and the app draws that window's content into the PNG itself and quits; this needs no Screen
/// Recording permission. Normal launches are unaffected.
enum ScreenshotScene: String {
    /// The menu bar panel with a paused session and an update available.
    case panel
    /// The General tab of the settings.
    case settings
    /// The Shortcuts tab with two global shortcuts.
    case shortcut
    /// The update prompt for version 1.3.
    case update

    static var current: ScreenshotScene? {
        argument(after: "-screenshot").flatMap(ScreenshotScene.init(rawValue:))
    }

    /// Where `-render-screenshot` asks the PNG to be written.
    static var renderPath: String? {
        argument(after: "-render-screenshot")
    }

    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    /// The window size in points. The PNG is twice as large.
    var size: CGSize {
        switch self {
        case .panel: CGSize(width: 440, height: 640)
        case .settings, .shortcut: CGSize(width: 600, height: 500)
        case .update: CGSize(width: 560, height: 440)
        }
    }

    @MainActor
    @ViewBuilder
    func content(model: AppModel) -> some View {
        switch self {
        case .panel:
            TempoPanel(model: model)
        case .settings:
            TempoSettings(model: model, selection: .general)
        case .shortcut:
            TempoSettings(model: model, selection: .shortcuts)
        case .update:
            UpdatePromptView(
                release: DemoContent.release,
                currentVersion: "1.2",
                appName: "Tempo",
                onDownload: {},
                onSkip: {},
                onRemindLater: {}
            )
        }
    }
}

/// A soft background with the scene on a card, plus a strip of menu bar above the panel.
private struct ScreenshotBackdrop<Content: View>: View {
    let scene: ScreenshotScene
    @ObservedObject var timer: FocusTimer
    let content: Content

    init(scene: ScreenshotScene, timer: FocusTimer, @ViewBuilder content: () -> Content) {
        self.scene = scene
        self._timer = ObservedObject(wrappedValue: timer)
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.86, blue: 0.72), Color(red: 0.80, green: 0.84, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if scene == .panel {
                VStack(alignment: .trailing, spacing: 6) {
                    // A slice of the menu bar with the status item, highlighted as when it is open.
                    HStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "wifi")
                        Image(systemName: "battery.75percent")
                        MenuBarLabel(title: "Tempo", systemImage: "timer", statusTitle: timer.menuBarTitle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        Text(verbatim: "Thu 9:41")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.55))

                    card
                        .padding(.trailing, 40)
                }
            } else {
                card
                    .padding(36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: scene.size.width, height: scene.size.height)
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
    }

    private var card: some View {
        content
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

/// The window a screenshot scene is shown in, and the renderer that turns it into a PNG.
@MainActor
final class ScreenshotWindow {
    private let window: NSWindow

    init(scene: ScreenshotScene, renderPath: String?) {
        let model = AppModel.shared
        if scene == .panel {
            model.timer.showPausedSession(remaining: 18 * 60 + 42)
        }

        // A normal (not borderless) window, with the title bar hidden so the content fills it.
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: scene.size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Tempo – \(scene.rawValue)"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AnyView(
            ScreenshotBackdrop(scene: scene, timer: model.timer) {
                scene.content(model: model)
            }
        ))
        window.setContentSize(scene.size)
        window.center()

        // An agent app (LSUIElement) can show windows, but a regular one is sure to be in front.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)

        Task {
            if scene == .panel {
                // Shows the "Version 1.3 is available" banner. The feed is bundled, so this is instant.
                await model.updates.checkForUpdates(userInitiated: true)
            }
            // Give SwiftUI and AppKit time to lay out and draw forms, switches and symbols.
            try? await Task.sleep(for: .seconds(2.5))
            if let renderPath {
                self.render(to: renderPath)
            }
        }
    }

    /// Draws the window's content view into a 2x bitmap, refuses a blank result, writes the PNG
    /// and quits. Exits with status 1 on any failure so the CI script can retry or fall back.
    private func render(to path: String) {
        guard let view = window.contentView else { return fail("The window has no content view") }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        let bounds = view.bounds
        let scale: CGFloat = 2
        guard bounds.width > 0, bounds.height > 0,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: Int(bounds.width * scale),
                  pixelsHigh: Int(bounds.height * scale),
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              )
        else { return fail("Could not create a bitmap for \(bounds)") }

        // The bitmap's size in points against its pixel size makes the view draw at 2x.
        bitmap.size = bounds.size
        view.cacheDisplay(in: bounds, to: bitmap)

        guard Self.distinctColorCount(in: bitmap) > 24 else {
            return fail("The rendered image is blank")
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            return fail("Could not encode the PNG")
        }
        do {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            return fail("Could not write \(path): \(error.localizedDescription)")
        }
        print("Rendered \(path) (\(bitmap.pixelsWide)x\(bitmap.pixelsHigh), \(png.count) bytes)")
        exit(0)
    }

    /// Samples a grid of pixels. A blank or single-color image has only a handful of colors.
    private static func distinctColorCount(in bitmap: NSBitmapImageRep) -> Int {
        var colors = Set<UInt32>()
        let step = max(1, min(bitmap.pixelsWide, bitmap.pixelsHigh) / 60)
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: step) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: step) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                colors.insert(channel(color.redComponent) << 16 | channel(color.greenComponent) << 8 | channel(color.blueComponent))
            }
        }
        return colors.count
    }

    private static func channel(_ component: CGFloat) -> UInt32 {
        UInt32(min(255, max(0, (component * 255).rounded())))
    }

    private func fail(_ message: String) {
        FileHandle.standardError.write(Data("Screenshot failed: \(message)\n".utf8))
        exit(1)
    }
}
