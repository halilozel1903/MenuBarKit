import Foundation

/// Formatting for the short text next to a menu bar icon.
///
/// Menu bar space is scarce and the text changes often, so every helper returns something short,
/// never negative and stable in width where it can be.
///
/// ```swift
/// StatusItemTitle.count(3)                 // "3"
/// StatusItemTitle.count(250)               // "99+"
/// StatusItemTitle.countdown(1_453)         // "24:13"
/// StatusItemTitle.percent(0.423)           // "42%"
/// StatusItemTitle.truncated("Deploying production", maxLength: 12) // "Deploying p…"
/// StatusItemTitle.join(["24:13", nil, "3"]) // "24:13 · 3"
/// ```
public enum StatusItemTitle {
    /// A badge count. `""` for zero or less, so the title disappears; `"99+"` above `limit`.
    public static func count(_ value: Int, limit: Int = 99) -> String {
        guard value > 0 else { return "" }
        let limit = max(1, limit)
        return value > limit ? "\(limit)+" : "\(value)"
    }

    /// A timer: `"4:05"` below an hour, `"1:02:03"` from an hour. Negative values show `"0:00"`,
    /// fractions round up so a countdown shows `"0:01"` until it really is over.
    public static func countdown(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours):\(twoDigits(minutes)):\(twoDigits(secs))"
        }
        return "\(minutes):\(twoDigits(secs))"
    }

    /// A fraction from 0 to 1 as a whole percentage, clamped: `0.423` → `"42%"`, `1.7` → `"100%"`.
    public static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "0%" }
        let clamped = min(1, max(0, fraction))
        return "\(Int((clamped * 100).rounded()))%"
    }

    /// Trims whitespace and newlines, collapses inner runs of whitespace, and cuts the text to
    /// `maxLength` characters including a trailing `…`.
    public static func truncated(_ text: String, maxLength: Int) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let collapsed = words.joined(separator: " ")
        guard maxLength > 0 else { return "" }
        guard collapsed.count > maxLength else { return collapsed }
        if maxLength == 1 { return "…" }
        let prefix = collapsed.prefix(maxLength - 1).trimmingCharacters(in: .whitespaces)
        return prefix + "…"
    }

    /// Joins the non-empty parts with a middle dot: `["24:13", nil, "", "3"]` → `"24:13 · 3"`.
    public static func join(_ parts: [String?], separator: String = " · ") -> String {
        parts.compactMap { part in
            guard let part, !part.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return part
        }
        .joined(separator: separator)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
