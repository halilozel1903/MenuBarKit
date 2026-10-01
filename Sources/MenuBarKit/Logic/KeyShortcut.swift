import Foundation

/// A keyboard shortcut such as ⌥⌘T: one key plus modifier keys.
///
/// `KeyShortcut` is a plain value. It parses the strings people write, shows itself the way the
/// menu bar does (modifiers in the order ⌃⌥⇧⌘), and knows the virtual key code and Carbon
/// modifier mask that ``HotKeyCenter`` registers with the system.
///
/// ```swift
/// KeyShortcut("⌘⇧K")                 // ⇧⌘K
/// KeyShortcut("ctrl+option+space")   // ⌃⌥Space
/// KeyShortcut("Command-Shift-K")     // ⇧⌘K
/// KeyShortcut(.k, modifiers: [.command, .shift]).displayString // "⇧⌘K"
/// ```
public struct KeyShortcut: Sendable, Hashable, Codable, CustomStringConvertible {
    public var key: Key
    public var modifiers: Modifiers

    public init(_ key: Key, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Parses glyph strings (`"⌘⇧K"`, `"⌥⌘←"`) and words joined by `+` or `-`
    /// (`"cmd+shift+k"`, `"Control-Option-Space"`). Modifiers may come in any order.
    /// Returns `nil` when the key is missing or unknown, or a modifier word is not recognized.
    public init?(_ string: String) {
        var rest = Substring(string.trimmingCharacters(in: .whitespaces))
        var modifiers: Modifiers = []

        // Leading modifier glyphs: "⌘⇧K".
        while let first = rest.first, let modifier = Modifiers(glyph: first) {
            modifiers.insert(modifier)
            rest = rest.dropFirst()
        }

        // Words: "cmd+shift+k" or "Command-Shift-K". A single remaining character is always the key,
        // so "⌘-" and "⌘=" keep working.
        let separator: Character? = rest.contains("+") ? "+" : (rest.contains("-") ? "-" : nil)
        if rest.count > 1, let separator {
            var parts = rest.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
            // "cmd+-" or "cmd--": the empty tail means the separator itself is the key.
            if parts.count >= 2, parts[parts.count - 1].isEmpty, parts[parts.count - 2].isEmpty {
                parts.removeLast(2)
                parts.append(String(separator))
            }
            guard let keyName = parts.popLast(), !keyName.isEmpty else { return nil }
            for word in parts where !word.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let modifier = Modifiers(word: word) else { return nil }
                modifiers.insert(modifier)
            }
            rest = Substring(keyName)
        }

        guard let key = Key(name: String(rest)) else { return nil }
        self.init(key, modifiers: modifiers)
    }

    /// The shortcut as macOS shows it in menus: `"⌃⌥⇧⌘K"`, `"⌥⌘Space"`, `"⌘F5"`.
    public var displayString: String {
        modifiers.displayString + key.displayName
    }

    public var description: String { displayString }

    /// `true` when the shortcut is safe to register globally: it has ⌘, ⌥ or ⌃ (⇧ alone would
    /// steal a capital letter from every app), or the key is a function key.
    public var isValidGlobalShortcut: Bool {
        if key.isFunctionKey { return true }
        return !modifiers.intersection([.command, .option, .control]).isEmpty
    }

    /// The modifier mask Carbon's `RegisterEventHotKey` expects.
    public var carbonModifiers: UInt32 { modifiers.carbonFlags }
}

// MARK: - Modifiers

extension KeyShortcut {
    /// The modifier keys of a shortcut.
    public struct Modifiers: OptionSet, Sendable, Hashable, Codable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        /// The order macOS uses in menus.
        static let displayOrder: [(Modifiers, Character)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]

        /// `"⌃⌥⇧⌘"` for all four, in menu order.
        public var displayString: String {
            String(Self.displayOrder.compactMap { contains($0.0) ? $0.1 : nil })
        }

        init?(glyph: Character) {
            switch glyph {
            case "⌘": self = .command
            case "⇧": self = .shift
            case "⌥": self = .option
            case "⌃": self = .control
            default: return nil
            }
        }

        init?(word: String) {
            let trimmed = word.trimmingCharacters(in: .whitespaces)
            if trimmed.count == 1, let glyph = trimmed.first, let modifier = Modifiers(glyph: glyph) {
                self = modifier
                return
            }
            switch trimmed.lowercased() {
            case "cmd", "command", "meta", "super": self = .command
            case "shift": self = .shift
            case "opt", "option", "alt": self = .option
            case "ctrl", "control", "ctl": self = .control
            default: return nil
            }
        }

        /// Carbon's `cmdKey`, `shiftKey`, `optionKey` and `controlKey` (Events.h).
        public var carbonFlags: UInt32 {
            var flags: UInt32 = 0
            if contains(.command) { flags |= 0x0100 }
            if contains(.shift) { flags |= 0x0200 }
            if contains(.option) { flags |= 0x0800 }
            if contains(.control) { flags |= 0x1000 }
            return flags
        }
    }
}

// MARK: - Keys

extension KeyShortcut {
    /// A key on the keyboard, identified by its virtual key code (`kVK_*` in Carbon's Events.h).
    /// Codes refer to key positions on an ANSI (US) layout.
    public struct Key: Sendable, Hashable, Codable, CustomStringConvertible {
        /// The virtual key code, for example `0x28` for K.
        public let keyCode: UInt16
        /// How the key is shown: `"K"`, `"Space"`, `"↩"`, `"F5"`.
        public let displayName: String

        /// The key for a virtual key code, or `nil` when the code is not one of the keys MenuBarKit knows.
        public init?(keyCode: UInt16) {
            guard let key = Self.all.first(where: { $0.keyCode == keyCode }) else { return nil }
            self = key
        }

        private init(_ keyCode: UInt16, _ displayName: String) {
            self.keyCode = keyCode
            self.displayName = displayName
        }

        /// Keys are stored as their key code only.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let code = try container.decode(UInt16.self)
            guard let key = Key(keyCode: code) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown key code \(code)")
            }
            self = key
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(keyCode)
        }

        /// A key by name or glyph: `"k"`, `"K"`, `"space"`, `"return"`, `"↩"`, `"esc"`, `"left"`, `"←"`, `"f5"`.
        public init?(name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                // A lone space character means the space bar.
                if name == " " { self = .space; return }
                return nil
            }
            let lowered = trimmed.lowercased()
            if let key = Self.all.first(where: { $0.displayName.lowercased() == lowered }) {
                self = key
                return
            }
            guard let code = Self.aliases[lowered], let key = Key(keyCode: code) else { return nil }
            self = key
        }

        public var description: String { displayName }

        /// F1 to F20.
        public var isFunctionKey: Bool { Self.functionKeyCodes.contains(keyCode) }

        /// The single character the key types without modifiers, such as `"k"` or `"["`; `nil` for
        /// named keys such as Space, arrows and F-keys.
        public var character: Character? {
            guard displayName.count == 1, let first = displayName.first, first.isASCII else { return nil }
            return Character(first.lowercased())
        }

        // MARK: Table

        public static let a = Key(0x00, "A")
        public static let s = Key(0x01, "S")
        public static let d = Key(0x02, "D")
        public static let f = Key(0x03, "F")
        public static let h = Key(0x04, "H")
        public static let g = Key(0x05, "G")
        public static let z = Key(0x06, "Z")
        public static let x = Key(0x07, "X")
        public static let c = Key(0x08, "C")
        public static let v = Key(0x09, "V")
        public static let b = Key(0x0B, "B")
        public static let q = Key(0x0C, "Q")
        public static let w = Key(0x0D, "W")
        public static let e = Key(0x0E, "E")
        public static let r = Key(0x0F, "R")
        public static let y = Key(0x10, "Y")
        public static let t = Key(0x11, "T")
        public static let one = Key(0x12, "1")
        public static let two = Key(0x13, "2")
        public static let three = Key(0x14, "3")
        public static let four = Key(0x15, "4")
        public static let six = Key(0x16, "6")
        public static let five = Key(0x17, "5")
        public static let equal = Key(0x18, "=")
        public static let nine = Key(0x19, "9")
        public static let seven = Key(0x1A, "7")
        public static let minus = Key(0x1B, "-")
        public static let eight = Key(0x1C, "8")
        public static let zero = Key(0x1D, "0")
        public static let rightBracket = Key(0x1E, "]")
        public static let o = Key(0x1F, "O")
        public static let u = Key(0x20, "U")
        public static let leftBracket = Key(0x21, "[")
        public static let i = Key(0x22, "I")
        public static let p = Key(0x23, "P")
        public static let returnKey = Key(0x24, "↩")
        public static let l = Key(0x25, "L")
        public static let j = Key(0x26, "J")
        public static let quote = Key(0x27, "'")
        public static let k = Key(0x28, "K")
        public static let semicolon = Key(0x29, ";")
        public static let backslash = Key(0x2A, "\\")
        public static let comma = Key(0x2B, ",")
        public static let slash = Key(0x2C, "/")
        public static let n = Key(0x2D, "N")
        public static let m = Key(0x2E, "M")
        public static let period = Key(0x2F, ".")
        public static let tab = Key(0x30, "⇥")
        public static let space = Key(0x31, "Space")
        public static let grave = Key(0x32, "`")
        public static let delete = Key(0x33, "⌫")
        public static let escape = Key(0x35, "⎋")
        public static let f1 = Key(0x7A, "F1")
        public static let f2 = Key(0x78, "F2")
        public static let f3 = Key(0x63, "F3")
        public static let f4 = Key(0x76, "F4")
        public static let f5 = Key(0x60, "F5")
        public static let f6 = Key(0x61, "F6")
        public static let f7 = Key(0x62, "F7")
        public static let f8 = Key(0x64, "F8")
        public static let f9 = Key(0x65, "F9")
        public static let f10 = Key(0x6D, "F10")
        public static let f11 = Key(0x67, "F11")
        public static let f12 = Key(0x6F, "F12")
        public static let f13 = Key(0x69, "F13")
        public static let f14 = Key(0x6B, "F14")
        public static let f15 = Key(0x71, "F15")
        public static let f16 = Key(0x6A, "F16")
        public static let f17 = Key(0x40, "F17")
        public static let f18 = Key(0x4F, "F18")
        public static let f19 = Key(0x50, "F19")
        public static let f20 = Key(0x5A, "F20")
        public static let home = Key(0x73, "↖")
        public static let pageUp = Key(0x74, "⇞")
        public static let forwardDelete = Key(0x75, "⌦")
        public static let end = Key(0x77, "↘")
        public static let pageDown = Key(0x79, "⇟")
        public static let leftArrow = Key(0x7B, "←")
        public static let rightArrow = Key(0x7C, "→")
        public static let downArrow = Key(0x7D, "↓")
        public static let upArrow = Key(0x7E, "↑")

        /// Every key MenuBarKit can show and register.
        public static let all: [Key] = [
            a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
            zero, one, two, three, four, five, six, seven, eight, nine,
            equal, minus, leftBracket, rightBracket, quote, semicolon, backslash, comma, slash, period, grave,
            returnKey, tab, space, delete, escape, forwardDelete,
            home, end, pageUp, pageDown, leftArrow, rightArrow, downArrow, upArrow,
            f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16, f17, f18, f19, f20,
        ]

        static let functionKeyCodes: Set<UInt16> = Set(
            [f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15, f16, f17, f18, f19, f20].map(\.keyCode)
        )

        /// Lowercased names accepted by `init(name:)` besides the display names.
        static let aliases: [String: UInt16] = [
            "return": 0x24, "enter": 0x24,
            "tab": 0x30,
            "space": 0x31, "spacebar": 0x31, "␣": 0x31,
            "delete": 0x33, "backspace": 0x33,
            "escape": 0x35, "esc": 0x35,
            "forwarddelete": 0x75, "fwddelete": 0x75, "del": 0x75,
            "home": 0x73, "end": 0x77,
            "pageup": 0x74, "pgup": 0x74, "pagedown": 0x79, "pgdn": 0x79,
            "left": 0x7B, "leftarrow": 0x7B,
            "right": 0x7C, "rightarrow": 0x7C,
            "down": 0x7D, "downarrow": 0x7D,
            "up": 0x7E, "uparrow": 0x7E,
            "equal": 0x18, "equals": 0x18, "plus": 0x18,
            "minus": 0x1B, "hyphen": 0x1B, "dash": 0x1B,
            "comma": 0x2B, "period": 0x2F, "dot": 0x2F, "slash": 0x2C, "backslash": 0x2A,
            "semicolon": 0x29, "quote": 0x27, "grave": 0x32, "backtick": 0x32,
            "leftbracket": 0x21, "rightbracket": 0x1E,
        ]
    }
}
