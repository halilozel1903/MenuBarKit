import Carbon.HIToolbox
import Foundation

/// Registers system-wide keyboard shortcuts with Carbon's `RegisterEventHotKey`.
///
/// Carbon hot keys work while any app is active, need no Accessibility or Input Monitoring
/// permission and are not affected by the App Sandbox. The handler always runs on the main actor.
///
/// ```swift
/// let id = HotKeyCenter.shared.register(KeyShortcut("⌥⌘T")!) {
///     timer.toggle()
/// }
/// HotKeyCenter.shared.unregister(id)
/// ```
///
/// Most apps use ``GlobalShortcut`` instead, which also stores the user's choice.
@MainActor
public final class HotKeyCenter {
    /// Identifies one registration.
    public struct Registration: Sendable, Hashable {
        public let id: UInt32
        public let shortcut: KeyShortcut
    }

    /// Why a shortcut could not be registered.
    public enum RegistrationError: Error, Sendable, Equatable {
        /// The shortcut has no ⌘, ⌥ or ⌃ and is not a function key.
        case invalidShortcut
        /// Another app (or this one) already owns the shortcut, or Carbon refused it. Holds the `OSStatus`.
        case systemError(Int32)
    }

    public static let shared = HotKeyCenter()

    /// While `true`, pressed hot keys are ignored. ``ShortcutRecorder`` sets it while it records,
    /// so pressing the current shortcut records it instead of running its action.
    public var isPaused = false

    private struct Entry {
        let shortcut: KeyShortcut
        let reference: EventHotKeyRef
        let action: () -> Void
    }

    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1
    private var handlerReference: EventHandlerRef?

    private init() {}

    /// The shortcuts registered right now.
    public var registrations: [Registration] {
        entries.map { Registration(id: $0.key, shortcut: $0.value.shortcut) }.sorted { $0.id < $1.id }
    }

    /// Registers a system-wide shortcut. The action runs on the main actor each time it is pressed.
    @discardableResult
    public func register(_ shortcut: KeyShortcut, action: @escaping () -> Void) throws -> Registration {
        guard shortcut.isValidGlobalShortcut else { throw RegistrationError.invalidShortcut }
        try installHandlerIfNeeded()

        let id = nextID
        nextID &+= 1
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.key.keyCode),
            shortcut.carbonModifiers,
            EventHotKeyID(signature: menuBarKitHotKeySignature, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw RegistrationError.systemError(status)
        }
        entries[id] = Entry(shortcut: shortcut, reference: reference, action: action)
        return Registration(id: id, shortcut: shortcut)
    }

    /// Removes a registration. Unknown registrations are ignored.
    public func unregister(_ registration: Registration) {
        guard let entry = entries.removeValue(forKey: registration.id) else { return }
        UnregisterEventHotKey(entry.reference)
    }

    /// Removes every shortcut registered through this center.
    public func unregisterAll() {
        for entry in entries.values {
            UnregisterEventHotKey(entry.reference)
        }
        entries.removeAll()
    }

    /// Runs the action of a pressed hot key. Called by the Carbon event handler.
    fileprivate func handlePress(id: UInt32) {
        guard !isPaused, let entry = entries[id] else { return }
        entry.action()
    }

    private func installHandlerIfNeeded() throws {
        guard handlerReference == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var reference: EventHandlerRef?
        // `menuBarKitHotKeyHandler` is a global function without captures, so it converts to the
        // `@convention(c)` pointer Carbon expects.
        let status = InstallEventHandler(GetEventDispatcherTarget(), menuBarKitHotKeyHandler, 1, &eventType, nil, &reference)
        guard status == noErr else { throw RegistrationError.systemError(status) }
        handlerReference = reference
    }
}

/// The four-character code `MBKT` that marks MenuBarKit's hot keys.
private let menuBarKitHotKeySignature: OSType = 0x4D42_4B54

/// The Carbon callback. It reads the hot key's ID from the event and hands it to the main actor.
/// Carbon delivers hot key events on the main thread; hopping through a task keeps this correct even
/// if that ever changes, at the cost of one run loop turn.
private func menuBarKitHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    guard hotKeyID.signature == menuBarKitHotKeySignature else { return OSStatus(eventNotHandledErr) }
    let id = hotKeyID.id
    Task { @MainActor in
        HotKeyCenter.shared.handlePress(id: id)
    }
    return noErr
}
