import Foundation

/// The rules ``ShortcutRecorder`` applies to a key press while it records.
public enum ShortcutRecording {
    /// What a key press means to the recorder.
    public enum Action: Sendable, Hashable {
        /// Use this shortcut.
        case record(KeyShortcut)
        /// Remove the shortcut: ⌫ or ⌦ without modifiers.
        case clear
        /// Stop recording and keep the old shortcut: ⎋ without modifiers.
        case cancel
        /// Not usable as a global shortcut, such as a plain letter, ⇧K or an unknown key.
        case reject
    }

    /// Interprets one key press made while recording.
    public static func interpret(keyCode: UInt16, modifiers: KeyShortcut.Modifiers) -> Action {
        guard let key = KeyShortcut.Key(keyCode: keyCode) else { return .reject }
        if modifiers.isEmpty {
            if key == .escape { return .cancel }
            if key == .delete || key == .forwardDelete { return .clear }
        }
        let shortcut = KeyShortcut(key, modifiers: modifiers)
        return shortcut.isValidGlobalShortcut ? .record(shortcut) : .reject
    }
}
