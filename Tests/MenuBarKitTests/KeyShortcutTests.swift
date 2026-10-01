import Foundation
import Testing
@testable import MenuBarKit

@Suite("KeyShortcut parsing and display")
struct KeyShortcutTests {
    @Test(arguments: [
        ("⌘⇧K", "⇧⌘K"),
        ("⇧⌘K", "⇧⌘K"),
        ("⌘⇧k", "⇧⌘K"),
        ("cmd+shift+k", "⇧⌘K"),
        ("Command-Shift-K", "⇧⌘K"),
        ("shift + cmd + K", "⇧⌘K"),
        ("ctrl+option+space", "⌃⌥Space"),
        ("⌃⌥Space", "⌃⌥Space"),
        ("alt+cmd+left", "⌥⌘←"),
        ("⌥⌘←", "⌥⌘←"),
        ("control+opt+shift+cmd+t", "⌃⌥⇧⌘T"),
        ("cmd+return", "⌘↩"),
        ("cmd+esc", "⌘⎋"),
        ("cmd+f5", "⌘F5"),
        ("F12", "F12"),
        ("⌘,", "⌘,"),
        ("⌘-", "⌘-"),
        ("cmd+-", "⌘-"),
        ("cmd--", "⌘-"),
        ("cmd+=", "⌘="),
        ("⌥⌘1", "⌥⌘1"),
        ("⌘ + K", "⌘K"),
    ])
    func parsesAndDisplays(input: String, display: String) throws {
        let shortcut = try #require(KeyShortcut(input))
        #expect(shortcut.displayString == display)
    }

    @Test(arguments: ["", "⌘", "cmd+", "cmd+shift", "hyper+k", "cmd+kk", "⌘⇧😀", "cmd+f99", "++"])
    func rejectsInvalidStrings(input: String) {
        #expect(KeyShortcut(input) == nil)
    }

    @Test func displayOrderIsControlOptionShiftCommand() {
        let shortcut = KeyShortcut(.k, modifiers: [.command, .shift, .option, .control])
        #expect(shortcut.displayString == "⌃⌥⇧⌘K")
        #expect(shortcut.description == "⌃⌥⇧⌘K")
    }

    @Test func displayStringRoundTrips() {
        for key in KeyShortcut.Key.all {
            let shortcut = KeyShortcut(key, modifiers: [.option, .command])
            #expect(KeyShortcut(shortcut.displayString) == shortcut, "\(shortcut.displayString)")
        }
    }

    @Test func keyCodesMatchCarbon() {
        #expect(KeyShortcut.Key.a.keyCode == 0x00)
        #expect(KeyShortcut.Key.k.keyCode == 0x28)
        #expect(KeyShortcut.Key.t.keyCode == 0x11)
        #expect(KeyShortcut.Key.space.keyCode == 0x31)
        #expect(KeyShortcut.Key.returnKey.keyCode == 0x24)
        #expect(KeyShortcut.Key.f1.keyCode == 0x7A)
        #expect(KeyShortcut.Key.upArrow.keyCode == 0x7E)
        #expect(KeyShortcut.Key(keyCode: 0x28) == .k)
        #expect(KeyShortcut.Key(keyCode: 0xFF) == nil)
    }

    @Test func keyCodesAreUnique() {
        let codes = KeyShortcut.Key.all.map(\.keyCode)
        #expect(Set(codes).count == codes.count)
        let names = KeyShortcut.Key.all.map { $0.displayName.lowercased() }
        #expect(Set(names).count == names.count)
    }

    @Test func carbonModifierMask() {
        #expect(KeyShortcut.Modifiers.command.carbonFlags == 0x0100)
        #expect(KeyShortcut.Modifiers.shift.carbonFlags == 0x0200)
        #expect(KeyShortcut.Modifiers.option.carbonFlags == 0x0800)
        #expect(KeyShortcut.Modifiers.control.carbonFlags == 0x1000)
        let shortcut = KeyShortcut(.k, modifiers: [.command, .shift])
        #expect(shortcut.carbonModifiers == 0x0300)
    }

    @Test func globalShortcutValidity() {
        #expect(KeyShortcut(.k, modifiers: [.command]).isValidGlobalShortcut)
        #expect(KeyShortcut(.space, modifiers: [.control, .option]).isValidGlobalShortcut)
        #expect(KeyShortcut(.f5, modifiers: []).isValidGlobalShortcut)
        #expect(!KeyShortcut(.k, modifiers: []).isValidGlobalShortcut)
        #expect(!KeyShortcut(.k, modifiers: [.shift]).isValidGlobalShortcut)
    }

    @Test func characters() {
        #expect(KeyShortcut.Key.k.character == "k")
        #expect(KeyShortcut.Key.comma.character == ",")
        #expect(KeyShortcut.Key.space.character == nil)
        #expect(KeyShortcut.Key.leftArrow.character == nil)
        #expect(KeyShortcut.Key.f5.character == nil)
    }

    @Test func codableStoresKeyCodeAndModifiers() throws {
        let shortcut = KeyShortcut(.t, modifiers: [.option, .command])
        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(KeyShortcut.self, from: data)
        #expect(decoded == shortcut)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(KeyShortcut.self, from: Data(#"{"key":255,"modifiers":8}"#.utf8))
        }
    }

    @Test func recorderInterpretsKeyPresses() {
        #expect(ShortcutRecording.interpret(keyCode: 0x28, modifiers: [.command, .shift]) == .record(KeyShortcut(.k, modifiers: [.command, .shift])))
        #expect(ShortcutRecording.interpret(keyCode: 0x35, modifiers: []) == .cancel)
        #expect(ShortcutRecording.interpret(keyCode: 0x33, modifiers: []) == .clear)
        #expect(ShortcutRecording.interpret(keyCode: 0x75, modifiers: []) == .clear)
        #expect(ShortcutRecording.interpret(keyCode: 0x28, modifiers: []) == .reject)
        #expect(ShortcutRecording.interpret(keyCode: 0x28, modifiers: [.shift]) == .reject)
        #expect(ShortcutRecording.interpret(keyCode: 0xFF, modifiers: [.command]) == .reject)
        #expect(ShortcutRecording.interpret(keyCode: 0x35, modifiers: [.command]) == .record(KeyShortcut(.escape, modifiers: [.command])))
        #expect(ShortcutRecording.interpret(keyCode: 0x60, modifiers: []) == .record(KeyShortcut(.f5, modifiers: [])))
    }
}
