import AppKit
import Combine
import SwiftUI

extension KeyShortcut.Modifiers {
    /// The modifiers of an AppKit event. Caps Lock, Fn and the numeric pad flag are ignored.
    public init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: KeyShortcut.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}

extension KeyShortcut {
    /// The shortcut of a key-down event, or `nil` for a key MenuBarKit does not know.
    public init?(event: NSEvent) {
        guard let key = Key(keyCode: event.keyCode) else { return nil }
        self.init(key, modifiers: Modifiers(event.modifierFlags))
    }

    /// The same shortcut for SwiftUI's `.keyboardShortcut(_:)`, for example to show it in a menu.
    /// `nil` for F-keys, which SwiftUI cannot express.
    public var keyboardShortcut: KeyboardShortcut? {
        let equivalent: KeyEquivalent
        switch key {
        case .returnKey: equivalent = .return
        case .tab: equivalent = .tab
        case .space: equivalent = .space
        case .delete: equivalent = .delete
        case .forwardDelete: equivalent = .deleteForward
        case .escape: equivalent = .escape
        case .home: equivalent = .home
        case .end: equivalent = .end
        case .pageUp: equivalent = .pageUp
        case .pageDown: equivalent = .pageDown
        case .leftArrow: equivalent = .leftArrow
        case .rightArrow: equivalent = .rightArrow
        case .upArrow: equivalent = .upArrow
        case .downArrow: equivalent = .downArrow
        default:
            guard let character = key.character else { return nil }
            equivalent = KeyEquivalent(character)
        }
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) { eventModifiers.insert(.command) }
        if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
        if modifiers.contains(.option) { eventModifiers.insert(.option) }
        if modifiers.contains(.control) { eventModifiers.insert(.control) }
        return KeyboardShortcut(equivalent, modifiers: eventModifiers)
    }
}

/// A button that records a keyboard shortcut, like the ones in System Settings.
///
/// Click it and press the new shortcut. ⎋ cancels, ⌫ removes the shortcut, and a shortcut
/// without ⌘, ⌥ or ⌃ is refused with a beep. While it records, ``HotKeyCenter`` is paused so the
/// current shortcut can be recorded again instead of running its action.
///
/// ```swift
/// ShortcutRecorder(shortcut: $shortcut)
/// ```
public struct ShortcutRecorder: View {
    @Binding private var shortcut: KeyShortcut?
    @StateObject private var recorder = ShortcutRecorderState()
    private let placeholder: LocalizedStringKey

    public init(shortcut: Binding<KeyShortcut?>, placeholder: LocalizedStringKey = "Record Shortcut") {
        self._shortcut = shortcut
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    recorder.start { newValue in
                        shortcut = newValue
                    }
                }
            } label: {
                label
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(recorder.isRecording ? .accentColor : nil)
            .accessibilityHint(Text("Click, then press the new shortcut"))

            if shortcut != nil && !recorder.isRecording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Text("Remove Shortcut"))
                .accessibilityLabel(Text("Remove Shortcut"))
            }
        }
        .onDisappear { recorder.stop() }
    }

    @ViewBuilder
    private var label: some View {
        if recorder.isRecording {
            Text(recorder.wasRejected ? "Add ⌘, ⌥ or ⌃" : "Type Shortcut…")
                .foregroundStyle(recorder.wasRejected ? Color.red : Color.accentColor)
        } else if let shortcut {
            Text(verbatim: shortcut.displayString)
                .monospaced()
        } else {
            Text(placeholder)
                .foregroundStyle(.secondary)
        }
    }
}

/// The recording state behind ``ShortcutRecorder``: a local key-down monitor while recording.
@MainActor
final class ShortcutRecorderState: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var wasRejected = false

    private var monitor: Any?
    private var onRecord: ((KeyShortcut?) -> Void)?

    func start(onRecord: @escaping (KeyShortcut?) -> Void) {
        stop()
        self.onRecord = onRecord
        isRecording = true
        wasRejected = false
        HotKeyCenter.shared.isPaused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            // Copy plain values out of the event before touching main-actor state.
            let keyCode = event.keyCode
            let modifiers = KeyShortcut.Modifiers(event.modifierFlags)
            MainActor.assumeIsolated {
                self.handle(ShortcutRecording.interpret(keyCode: keyCode, modifiers: modifiers))
            }
            // Swallow every key press while recording so it does not reach a text field or a menu.
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        onRecord = nil
        if isRecording {
            isRecording = false
            HotKeyCenter.shared.isPaused = false
        }
        wasRejected = false
    }

    private func handle(_ action: ShortcutRecording.Action) {
        switch action {
        case .record(let shortcut):
            onRecord?(shortcut)
            stop()
        case .clear:
            onRecord?(nil)
            stop()
        case .cancel:
            stop()
        case .reject:
            wasRejected = true
            NSSound.beep()
        }
    }
}
