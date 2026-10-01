import SwiftUI

/// A menu bar item that opens a window, set up the way menu bar apps need it: the `.window`
/// style, an SF Symbol with an optional short title next to it, and an optional binding that
/// removes the item from the menu bar.
///
/// ```swift
/// @main
/// struct TempoApp: App {
///     @StateObject private var timer = FocusTimer()
///
///     var body: some Scene {
///         MenuBarApp("Tempo", systemImage: "timer", statusTitle: timer.menuBarTitle) {
///             TempoPanel(timer: timer)
///         }
///         Settings {
///             TempoSettings()
///         }
///     }
/// }
/// ```
///
/// Add `LSUIElement` (Application is agent) = `YES` to the app's Info.plist so it has no Dock icon
/// and no main menu.
public struct MenuBarApp<Content: View>: Scene {
    private let title: String
    private let systemImage: String
    private let statusTitle: String
    private let isInserted: Binding<Bool>
    private let content: Content

    /// - Parameters:
    ///   - title: The app's name. VoiceOver reads it for the menu bar item.
    ///   - systemImage: The SF Symbol shown in the menu bar.
    ///   - statusTitle: Short text next to the symbol, such as `"24:13"` or `"3"`. Empty shows the symbol only.
    ///     ``StatusItemTitle`` formats common values.
    ///   - isInserted: Whether the item is in the menu bar. The user can also remove it by ⌘-dragging it out.
    ///   - content: The window content, usually a ``MenuBarPanel``.
    public init(
        _ title: String,
        systemImage: String,
        statusTitle: String = "",
        isInserted: Binding<Bool> = .constant(true),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.statusTitle = statusTitle
        self.isInserted = isInserted
        self.content = content()
    }

    public var body: some Scene {
        MenuBarExtra(isInserted: isInserted) {
            content
        } label: {
            MenuBarLabel(title: title, systemImage: systemImage, statusTitle: statusTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar item's label. Menu bar items render a single `Text` or `Image`, so the symbol is
/// interpolated into the text when there is a title.
public struct MenuBarLabel: View {
    private let title: String
    private let systemImage: String
    private let statusTitle: String

    public init(title: String, systemImage: String, statusTitle: String = "") {
        self.title = title
        self.systemImage = systemImage
        self.statusTitle = statusTitle
    }

    public var body: some View {
        if statusTitle.isEmpty {
            Image(systemName: systemImage)
                .accessibilityLabel(Text(verbatim: title))
        } else {
            Text("\(Image(systemName: systemImage)) \(statusTitle)")
                .monospacedDigit()
                .accessibilityLabel(Text(verbatim: "\(title), \(statusTitle)"))
        }
    }
}
