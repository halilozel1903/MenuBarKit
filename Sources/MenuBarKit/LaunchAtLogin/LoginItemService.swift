import Foundation
import ServiceManagement

/// Whether the app is registered to open at login.
public enum LoginItemStatus: Sendable, Hashable {
    /// The app opens at login.
    case enabled
    /// The app is not registered.
    case notRegistered
    /// The app is registered, but the user has to allow it in System Settings › General › Login Items.
    case requiresApproval
    /// The system could not find the app, for example when it runs from a disk image or Xcode's build folder.
    case notFound
}

/// What ``LaunchAtLogin`` needs from the system. The default is ``MainAppLoginItemService``;
/// tests and previews pass their own.
@MainActor
public protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    /// Opens System Settings at Login Items so the user can approve the app.
    func openSystemSettings()
}

extension LoginItemService {
    public func openSystemSettings() {}
}

/// Registers the running app itself with `SMAppService.mainApp` (macOS 13 and later).
/// No helper app, no entitlement and no sandbox exception are needed.
@MainActor
public final class MainAppLoginItemService: LoginItemService {
    public init() {}

    public var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .notRegistered
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notRegistered
        }
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// A login item that lives in memory, for tests, previews and screenshots.
@MainActor
public final class InMemoryLoginItemService: LoginItemService {
    public var status: LoginItemStatus
    /// When set, `register()` and `unregister()` throw this error and leave `status` unchanged.
    public var failure: (any Error)?
    /// When `true`, `register()` leads to ``LoginItemStatus/requiresApproval`` instead of `enabled`.
    public var requiresApproval: Bool
    public private(set) var registerCount = 0
    public private(set) var unregisterCount = 0

    public init(status: LoginItemStatus = .notRegistered, requiresApproval: Bool = false) {
        self.status = status
        self.requiresApproval = requiresApproval
    }

    public func register() throws {
        registerCount += 1
        if let failure { throw failure }
        status = requiresApproval ? .requiresApproval : .enabled
    }

    public func unregister() throws {
        unregisterCount += 1
        if let failure { throw failure }
        status = .notRegistered
    }
}
