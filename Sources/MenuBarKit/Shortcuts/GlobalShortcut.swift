import AppKit
import Combine
import SwiftUI

/// A system-wide shortcut the user can change, stored in `UserDefaults` and registered with
/// ``HotKeyCenter`` whenever it changes.
///
/// ```swift
/// @MainActor
/// final class AppModel: ObservableObject {
///     lazy var togglePanel = GlobalShortcut("togglePanel", default: KeyShortcut("⌥⌘T")) { [weak self] in
///         self?.toggleTimer()
///     }
/// }
///
/// // In the Shortcuts tab of the settings:
/// ShortcutSettingRow("Start or pause the timer", shortcut: model.togglePanel)
/// ```
@MainActor
public final class GlobalShortcut: ObservableObject, Identifiable {
    /// The name under which the shortcut is stored, unique within the app.
    public let name: String
    /// The shortcut the app ships with; ``reset()`` goes back to it.
    public let defaultShortcut: KeyShortcut?

    /// The current shortcut, `nil` when the user removed it. Setting it stores and re-registers it.
    @Published public var shortcut: KeyShortcut? {
        didSet {
            guard shortcut != oldValue else { return }
            save()
            register()
        }
    }

    /// Set when the shortcut could not be registered, for example because another app owns it.
    @Published public private(set) var errorMessage: String?

    public var id: String { name }

    private let defaults: UserDefaults
    private let action: () -> Void
    private var registration: HotKeyCenter.Registration?

    /// - Parameters:
    ///   - name: A stable name, used for the `UserDefaults` key `MenuBarKit.shortcut.<name>`.
    ///   - defaultShortcut: The shortcut before the user changes it.
    ///   - defaults: Where the user's choice is kept.
    ///   - action: Runs on the main actor each time the shortcut is pressed, in any app.
    public init(
        _ name: String,
        default defaultShortcut: KeyShortcut? = nil,
        defaults: UserDefaults = .standard,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.defaultShortcut = defaultShortcut
        self.defaults = defaults
        self.action = action
        self.shortcut = Self.load(name: name, defaults: defaults, fallback: defaultShortcut)
        register()
    }

    /// Goes back to the default shortcut.
    public func reset() {
        shortcut = defaultShortcut
    }

    /// Stops listening until the shortcut is set again. The stored choice is kept.
    public func suspend() {
        if let registration {
            HotKeyCenter.shared.unregister(registration)
        }
        registration = nil
    }

    /// Registers the current shortcut again, for example after ``suspend()``.
    public func register() {
        suspend()
        errorMessage = nil
        guard let shortcut else { return }
        do {
            registration = try HotKeyCenter.shared.register(shortcut, action: action)
        } catch HotKeyCenter.RegistrationError.invalidShortcut {
            errorMessage = String(localized: "Use at least one of ⌘, ⌥ or ⌃.")
        } catch {
            errorMessage = String(localized: "\(shortcut.displayString) is already in use.")
        }
    }

    // MARK: Storage

    static func key(for name: String) -> String { "MenuBarKit.shortcut.\(name)" }

    /// The stored value is the display string (`"⌥⌘T"`), or an empty string when the user removed the shortcut.
    static func load(name: String, defaults: UserDefaults, fallback: KeyShortcut?) -> KeyShortcut? {
        guard let stored = defaults.string(forKey: key(for: name)) else { return fallback }
        return stored.isEmpty ? nil : KeyShortcut(stored)
    }

    private func save() {
        defaults.set(shortcut?.displayString ?? "", forKey: Self.key(for: name))
    }
}

/// A labeled row with a ``ShortcutRecorder`` for a ``GlobalShortcut``, for the Shortcuts tab.
public struct ShortcutSettingRow: View {
    private let title: LocalizedStringKey
    @ObservedObject private var globalShortcut: GlobalShortcut

    public init(_ title: LocalizedStringKey, shortcut: GlobalShortcut) {
        self.title = title
        self._globalShortcut = ObservedObject(wrappedValue: shortcut)
    }

    public var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 4) {
                ShortcutRecorder(shortcut: $globalShortcut.shortcut)
                if let message = globalShortcut.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } label: {
            Text(title)
        }
    }
}
