import AppKit
import SwiftUI

/// The tabs of a ``SettingsPane``.
public enum SettingsTab: String, Sendable, Hashable, CaseIterable, Identifiable {
    case general
    case shortcuts
    case about

    public var id: String { rawValue }
}

/// What the About tab shows. ``fromBundle(_:)`` reads it from the app's Info.plist.
public struct AboutInfo: Sendable, Hashable {
    public var appName: String
    public var version: String
    public var build: String?
    public var copyright: String?
    /// A one-line description under the name.
    public var tagline: String?
    /// Buttons such as "Website" or "Source Code".
    public var links: [Link]

    public struct Link: Sendable, Hashable, Identifiable {
        public var title: String
        public var url: URL
        public var id: URL { url }

        public init(_ title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    public init(
        appName: String,
        version: String,
        build: String? = nil,
        copyright: String? = nil,
        tagline: String? = nil,
        links: [Link] = []
    ) {
        self.appName = appName
        self.version = version
        self.build = build
        self.copyright = copyright
        self.tagline = tagline
        self.links = links
    }

    /// Name, version, build and copyright from a bundle's Info.plist.
    public static func fromBundle(_ bundle: Bundle = .main, tagline: String? = nil, links: [Link] = []) -> AboutInfo {
        func value(_ key: String) -> String? {
            (bundle.localizedInfoDictionary?[key] as? String) ?? (bundle.object(forInfoDictionaryKey: key) as? String)
        }
        return AboutInfo(
            appName: value("CFBundleDisplayName") ?? value("CFBundleName") ?? ProcessInfo.processInfo.processName,
            version: value("CFBundleShortVersionString") ?? "1.0",
            build: value("CFBundleVersion"),
            copyright: value("NSHumanReadableCopyright"),
            tagline: tagline,
            links: links
        )
    }

    /// `"Version 1.2 (34)"`, or `"Version 1.2"` without a build number or when it equals the version.
    public var versionLine: String {
        if let build, !build.isEmpty, build != version {
            return "Version \(version) (\(build))"
        }
        return "Version \(version)"
    }
}

/// A settings window with the tabs menu bar apps usually have: General, Shortcuts and About.
///
/// Put it in a `Settings` scene. The General tab ends with an "Open at Login" toggle; the About
/// tab is filled from the Info.plist.
///
/// ```swift
/// Settings {
///     SettingsPane(about: .fromBundle(tagline: "A calm focus timer")) {
///         Toggle("Play a sound when a session ends", isOn: $playsSound)
///     } shortcuts: {
///         ShortcutSettingRow("Start or pause the timer", shortcut: model.toggleShortcut)
///     }
/// }
/// ```
public struct SettingsPane<General: View, Shortcuts: View>: View {
    @State private var selection: SettingsTab
    private let about: AboutInfo
    private let showsLaunchAtLogin: Bool
    private let showsShortcuts: Bool
    private let launchAtLogin: LaunchAtLogin
    private let general: General
    private let shortcuts: Shortcuts

    /// - Parameters:
    ///   - selection: The tab shown first.
    ///   - about: The About tab's content.
    ///   - showsLaunchAtLogin: Adds an "Open at Login" toggle to the end of the General tab.
    ///   - launchAtLogin: The object behind that toggle; ``LaunchAtLogin/shared`` by default.
    ///   - general: The General tab's settings, as rows of a grouped form.
    ///   - shortcuts: The Shortcuts tab's rows, usually ``ShortcutSettingRow``s.
    public init(
        selection: SettingsTab = .general,
        about: AboutInfo = .fromBundle(),
        showsLaunchAtLogin: Bool = true,
        launchAtLogin: LaunchAtLogin = .shared,
        @ViewBuilder general: () -> General,
        @ViewBuilder shortcuts: () -> Shortcuts
    ) {
        self._selection = State(initialValue: selection)
        self.about = about
        self.showsLaunchAtLogin = showsLaunchAtLogin
        self.showsShortcuts = Shortcuts.self != EmptyView.self
        self.launchAtLogin = launchAtLogin
        self.general = general()
        self.shortcuts = shortcuts()
    }

    public var body: some View {
        TabView(selection: $selection) {
            Form {
                general
                if showsLaunchAtLogin {
                    Section {
                        LaunchAtLoginToggle(launchAtLogin: launchAtLogin)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
            .tag(SettingsTab.general)

            if showsShortcuts {
                Form {
                    Section {
                        shortcuts
                    } footer: {
                        Text("Click a shortcut, then press the new keys. Press ⌫ to remove it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)
            }

            AboutView(info: about)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 480)
        .frame(minHeight: 300)
    }
}

extension SettingsPane where Shortcuts == EmptyView {
    /// A settings pane without a Shortcuts tab.
    public init(
        selection: SettingsTab = .general,
        about: AboutInfo = .fromBundle(),
        showsLaunchAtLogin: Bool = true,
        launchAtLogin: LaunchAtLogin = .shared,
        @ViewBuilder general: () -> General
    ) {
        self.init(
            selection: selection, about: about, showsLaunchAtLogin: showsLaunchAtLogin,
            launchAtLogin: launchAtLogin, general: general, shortcuts: { EmptyView() }
        )
    }
}

/// The About tab: the app icon, name, version, tagline, links and copyright.
public struct AboutView: View {
    private let info: AboutInfo

    public init(info: AboutInfo) {
        self.info = info
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(verbatim: info.appName)
                .font(.title.weight(.semibold))
            Text(verbatim: info.versionLine)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .textSelection(.enabled)
            if let tagline = info.tagline {
                Text(verbatim: tagline)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            if !info.links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(info.links) { link in
                        SwiftUI.Link(destination: link.url) {
                            Text(verbatim: link.title)
                        }
                        .menuBarButtonStyle()
                    }
                }
                .padding(.top, 6)
            }
            if let copyright = info.copyright {
                Text(verbatim: copyright)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
