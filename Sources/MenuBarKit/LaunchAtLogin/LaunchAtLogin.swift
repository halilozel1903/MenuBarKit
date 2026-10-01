import Combine
import SwiftUI

/// The "Open at Login" setting, backed by `SMAppService.mainApp`.
///
/// The system is the source of truth: nothing is stored in `UserDefaults`, and ``refresh()`` reads
/// the current state again, for example after the user changed it in System Settings.
///
/// ```swift
/// @ObservedObject private var launchAtLogin = LaunchAtLogin.shared
///
/// Toggle("Open at Login", isOn: $launchAtLogin.isEnabled)
/// // or simply
/// LaunchAtLoginToggle()
/// ```
@MainActor
public final class LaunchAtLogin: ObservableObject {
    /// The state as the system last reported it.
    @Published public private(set) var status: LoginItemStatus
    /// A message for the last failed change, cleared by the next successful one.
    @Published public private(set) var errorMessage: String?

    private let service: any LoginItemService

    /// The app-wide instance, backed by `SMAppService.mainApp`.
    public static let shared = LaunchAtLogin()

    public init(service: any LoginItemService = MainAppLoginItemService()) {
        self.service = service
        self.status = service.status
    }

    /// `true` when the app opens at login, or will once the user approves it.
    /// Setting it registers or unregisters the app.
    public var isEnabled: Bool {
        get { status == .enabled || status == .requiresApproval }
        set { setEnabled(newValue) }
    }

    /// `true` when the app is registered but waits for approval in System Settings.
    public var requiresApproval: Bool { status == .requiresApproval }

    /// Registers or unregisters the app. Does nothing when the state already matches.
    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        status = service.status
    }

    /// Reads the state from the system again.
    public func refresh() {
        status = service.status
    }

    /// Opens System Settings › General › Login Items.
    public func openSystemSettings() {
        service.openSystemSettings()
    }
}

/// A ready-made "Open at Login" toggle with a hint when the user still has to approve the app.
public struct LaunchAtLoginToggle: View {
    @ObservedObject private var launchAtLogin: LaunchAtLogin
    private let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey = "Open at Login", launchAtLogin: LaunchAtLogin = .shared) {
        self.title = title
        self._launchAtLogin = ObservedObject(wrappedValue: launchAtLogin)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $launchAtLogin.isEnabled)
            if launchAtLogin.requiresApproval {
                HStack(spacing: 4) {
                    Text("Allow the app in Login Items to finish.")
                    Button("Open System Settings") {
                        launchAtLogin.openSystemSettings()
                    }
                    .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let message = launchAtLogin.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear { launchAtLogin.refresh() }
    }
}
