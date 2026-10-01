import AppKit
import SwiftUI

/// The content of a menu bar window: a header with the app's icon and name, your sections, and a
/// footer with Settings and Quit.
///
/// ```swift
/// MenuBarPanel("Tempo", subtitle: "Ready to focus", systemImage: "timer", tint: .orange) {
///     MenuBarSection("Focus") {
///         MenuBarRow("Start Focus", systemImage: "play.fill", tint: .orange, value: "25 min") { … }
///         MenuBarToggleRow("Do Not Disturb", systemImage: "moon.fill", tint: .indigo, isOn: $dnd)
///     }
/// }
/// ```
public struct MenuBarPanel<Content: View, Accessory: View>: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let systemImage: String
    private let tint: Color
    private let width: CGFloat
    private let footer: MenuBarFooter.Configuration
    private let content: Content
    private let accessory: Accessory

    /// - Parameters:
    ///   - title: The app's name, shown large in the header.
    ///   - subtitle: A status line under the title.
    ///   - systemImage: The SF Symbol in the header tile.
    ///   - tint: The header tile's color.
    ///   - width: The panel width. Menu bar windows are usually 280 to 360 points wide.
    ///   - footer: Which footer buttons to show.
    ///   - content: Sections and rows.
    ///   - accessory: A view at the trailing edge of the header, such as a status pill.
    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = .accentColor,
        width: CGFloat = 320,
        footer: MenuBarFooter.Configuration = .init(),
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.width = width
        self.footer = footer
        self.content = content()
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MenuBarIcon(systemImage: systemImage, tint: tint, size: 36)
                    .shadow(color: tint.opacity(0.35), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                accessory
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)

            if footer.isVisible {
                Divider().padding(.horizontal, 10)
                MenuBarFooter(footer)
            }
        }
        .frame(width: width)
    }
}

extension MenuBarPanel where Accessory == EmptyView {
    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = .accentColor,
        width: CGFloat = 320,
        footer: MenuBarFooter.Configuration = .init(),
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title, subtitle: subtitle, systemImage: systemImage, tint: tint, width: width,
            footer: footer, content: content, accessory: { EmptyView() }
        )
    }
}

/// The bottom bar of a ``MenuBarPanel``: Settings…, the app version and Quit.
public struct MenuBarFooter: View {
    /// Which parts of the footer to show.
    public struct Configuration: Sendable, Hashable {
        /// Show a Settings button that opens the app's `Settings` scene.
        public var showsSettings: Bool
        /// Show the app version (`CFBundleShortVersionString`) in the middle.
        public var showsVersion: Bool
        /// Show a Quit button.
        public var showsQuit: Bool

        public init(showsSettings: Bool = true, showsVersion: Bool = true, showsQuit: Bool = true) {
            self.showsSettings = showsSettings
            self.showsVersion = showsVersion
            self.showsQuit = showsQuit
        }

        /// No footer at all.
        public static let hidden = Configuration(showsSettings: false, showsVersion: false, showsQuit: false)

        var isVisible: Bool { showsSettings || showsVersion || showsQuit }
    }

    @Environment(\.openSettings) private var openSettings
    private let configuration: Configuration

    public init(_ configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public var body: some View {
        HStack(spacing: 8) {
            if configuration.showsSettings {
                Button {
                    // A menu bar app is not active while its window is open; activate it so the
                    // settings window comes to the front instead of opening behind other apps.
                    NSApplication.shared.activate()
                    openSettings()
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            Spacer(minLength: 4)
            if configuration.showsVersion, let version = SemanticVersion.current {
                Text(verbatim: "v\(version.shortDescription)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            if configuration.showsQuit {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.small)
        .menuBarButtonStyle()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
