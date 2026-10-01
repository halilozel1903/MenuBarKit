import Foundation

/// A semantic version such as `1.2.0` or `2.0.0-beta.3`.
///
/// Versions compare by the rules of [Semantic Versioning](https://semver.org): major, then minor,
/// then patch, and a pre-release (`2.0.0-beta`) comes before its release (`2.0.0`).
/// Build metadata (`+1234`) is accepted and ignored.
///
/// ```swift
/// SemanticVersion("1.2")              // 1.2.0
/// SemanticVersion("v2.0.0-rc.1")      // 2.0.0-rc.1
/// let version: SemanticVersion = "1.10"
/// version > "1.9"                     // true, not a string comparison
/// ```
public struct SemanticVersion: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int
    /// Dot-separated pre-release identifiers, for example `["beta", "3"]` for `-beta.3`. Empty for a release.
    public var prerelease: [String]

    public init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0, prerelease: [String] = []) {
        self.major = max(0, major)
        self.minor = max(0, minor)
        self.patch = max(0, patch)
        self.prerelease = prerelease.filter { !$0.isEmpty }
    }

    /// Parses `"1"`, `"1.2"`, `"1.2.3"`, `"v1.2"`, `"1.2.0-beta.2"` or `"1.2.0+42"`.
    /// Returns `nil` for anything else, such as `""`, `"1.x"`, `"1..2"` or `"1.2.3.4"`.
    public init?(_ string: String) {
        var text = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if let first = text.first, first == "v" || first == "V" {
            text = text.dropFirst()
        }
        if let plus = text.firstIndex(of: "+") {
            text = text[..<plus]
        }

        var identifiers: [String] = []
        if let dash = text.firstIndex(of: "-") {
            let suffix = text[text.index(after: dash)...]
            let parts = suffix.split(separator: ".", omittingEmptySubsequences: false)
            guard !parts.isEmpty else { return nil }
            for part in parts {
                guard !part.isEmpty,
                      part.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
                else { return nil }
                identifiers.append(String(part))
            }
            text = text[..<dash]
        }

        let numbers = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(numbers.count) else { return nil }
        var values: [Int] = []
        for number in numbers {
            guard !number.isEmpty, number.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(number) else {
                return nil
            }
            values.append(value)
        }
        while values.count < 3 { values.append(0) }
        self.init(values[0], values[1], values[2], prerelease: identifiers)
    }

    /// `true` for a pre-release such as `2.0.0-beta.1`.
    public var isPrerelease: Bool { !prerelease.isEmpty }

    /// The full version, for example `"1.2.0"` or `"2.0.0-beta.1"`.
    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }

    /// The version as people write it: `"1.2"` for `1.2.0`, `"1.2.3"`, `"2.0.0-beta.1"`.
    public var shortDescription: String {
        if prerelease.isEmpty && patch == 0 {
            return "\(major).\(minor)"
        }
        return description
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        return comparePrerelease(lhs.prerelease, rhs.prerelease)
    }

    /// Semantic Versioning precedence, item 11: a release beats any pre-release; numeric identifiers
    /// compare numerically and sort before alphanumeric ones; a longer list wins when all shared ones are equal.
    private static func comparePrerelease(_ lhs: [String], _ rhs: [String]) -> Bool {
        switch (lhs.isEmpty, rhs.isEmpty) {
        case (true, true), (true, false): return false
        case (false, true): return true
        case (false, false): break
        }
        for (left, right) in zip(lhs, rhs) where left != right {
            switch (Int(left), Int(right)) {
            case let (l?, r?): return l < r
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return left < right
            }
        }
        return lhs.count < rhs.count
    }

    // MARK: Codable as a string

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let version = SemanticVersion(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid version \"\(string)\"")
        }
        self = version
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension SemanticVersion: ExpressibleByStringLiteral {
    /// A version from a literal such as `"1.2"`. An invalid literal is a programmer error and becomes `0.0.0`.
    public init(stringLiteral value: String) {
        if let version = SemanticVersion(value) {
            self = version
        } else {
            assertionFailure("Invalid version literal \"\(value)\"")
            self.init(0)
        }
    }
}

extension SemanticVersion {
    /// The app's `CFBundleShortVersionString`, or `nil` when it is missing or not a version.
    public static var current: SemanticVersion? {
        version(of: .main)
    }

    /// The `CFBundleShortVersionString` of a bundle.
    public static func version(of bundle: Bundle) -> SemanticVersion? {
        (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap { SemanticVersion($0) }
    }

    /// The running macOS version, for example `26.0.0`.
    public static var operatingSystem: SemanticVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return SemanticVersion(version.majorVersion, version.minorVersion, version.patchVersion)
    }
}
