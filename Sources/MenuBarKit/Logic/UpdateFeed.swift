import Foundation

/// One release in an update feed.
public struct UpdateRelease: Sendable, Hashable, Codable, Identifiable {
    public var version: SemanticVersion
    /// Where the user downloads the release: a DMG, a ZIP or a release page.
    public var downloadURL: URL
    /// A short list of changes, shown as bullet points.
    public var notes: [String]
    /// The oldest macOS the release runs on, if it needs a newer one than the app does today.
    public var minimumSystemVersion: SemanticVersion?
    /// A critical release (a security fix) ignores "Skip This Version" and "Remind Me Later".
    public var isCritical: Bool

    public var id: SemanticVersion { version }

    public init(
        version: SemanticVersion,
        downloadURL: URL,
        notes: [String] = [],
        minimumSystemVersion: SemanticVersion? = nil,
        isCritical: Bool = false
    ) {
        self.version = version
        self.downloadURL = downloadURL
        self.notes = notes
        self.minimumSystemVersion = minimumSystemVersion
        self.isCritical = isCritical
    }

    enum CodingKeys: String, CodingKey {
        case version
        case downloadURL = "url"
        case notes
        case minimumSystemVersion
        case isCritical = "critical"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(SemanticVersion.self, forKey: .version)
        downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        // `notes` may be a list or a single string with one change per line.
        if let list = try? container.decodeIfPresent([String].self, forKey: .notes) {
            notes = list
        } else if let text = try container.decodeIfPresent(String.self, forKey: .notes) {
            notes = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } else {
            notes = []
        }
        minimumSystemVersion = try container.decodeIfPresent(SemanticVersion.self, forKey: .minimumSystemVersion)
        isCritical = try container.decodeIfPresent(Bool.self, forKey: .isCritical) ?? false
    }
}

/// A JSON update feed: either a single release or `{"releases": [...]}`.
///
/// ```json
/// {
///   "releases": [
///     {
///       "version": "1.3.0",
///       "url": "https://example.com/Tempo-1.3.0.dmg",
///       "notes": ["Focus statistics", "Faster launch"],
///       "minimumSystemVersion": "14.0",
///       "critical": false
///     }
///   ]
/// }
/// ```
public struct UpdateFeed: Sendable, Hashable, Codable {
    public var releases: [UpdateRelease]

    public init(releases: [UpdateRelease]) {
        self.releases = releases
    }

    /// Decodes a feed from JSON data.
    public static func decode(_ data: Data) throws -> UpdateFeed {
        try JSONDecoder().decode(UpdateFeed.self, from: data)
    }

    enum CodingKeys: String, CodingKey { case releases }

    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           container.contains(.releases) {
            releases = try container.decode([UpdateRelease].self, forKey: .releases)
        } else {
            releases = [try UpdateRelease(from: decoder)]
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(releases, forKey: .releases)
    }
}

/// What to do after reading the feed.
public enum UpdateDecision: Sendable, Hashable {
    /// No newer release, or none that is a release (pre-releases are ignored unless asked for).
    case upToDate
    /// Show the update prompt for this release.
    case available(UpdateRelease)
    /// The newest release is the one the user chose to skip.
    case skipped(UpdateRelease)
    /// The user asked to be reminded later and that time has not come yet.
    case postponed(UpdateRelease, until: Date)
    /// A newer release exists but needs a newer macOS than the one running.
    case requiresNewerSystem(UpdateRelease)

    /// The release the decision is about, if any.
    public var release: UpdateRelease? {
        switch self {
        case .upToDate:
            return nil
        case .available(let release), .skipped(let release), .requiresNewerSystem(let release):
            return release
        case .postponed(let release, _):
            return release
        }
    }

    /// `true` when the prompt should appear.
    public var shouldPrompt: Bool {
        if case .available = self { return true }
        return false
    }
}

/// The pure rules behind ``UpdateChecker``: which release, if any, to offer.
public struct UpdatePolicy: Sendable, Hashable {
    /// Offer pre-releases such as `2.0.0-beta.1`. Off by default.
    public var includesPrereleases: Bool

    public init(includesPrereleases: Bool = false) {
        self.includesPrereleases = includesPrereleases
    }

    /// Picks the newest release newer than `current` that runs on `system`, then applies the
    /// user's choices:
    ///
    /// - A version the user skipped is not offered again; a newer one is.
    /// - "Remind Me Later" holds the prompt back until `remindAfter`.
    /// - A critical release ignores both.
    /// - When only releases for a newer macOS exist, the result is ``UpdateDecision/requiresNewerSystem(_:)``.
    public func decide(
        current: SemanticVersion,
        feed: UpdateFeed,
        system: SemanticVersion,
        skippedVersion: SemanticVersion? = nil,
        remindAfter: Date? = nil,
        now: Date = Date()
    ) -> UpdateDecision {
        let newer = feed.releases
            .filter { $0.version > current }
            .filter { includesPrereleases || !$0.version.isPrerelease }
            .sorted { $0.version > $1.version }

        guard let newest = newer.first else { return .upToDate }

        let supported = newer.filter { release in
            guard let minimum = release.minimumSystemVersion else { return true }
            return system >= minimum
        }
        guard let candidate = supported.first else { return .requiresNewerSystem(newest) }

        // A critical fix anywhere between the current and the offered version makes the offer critical.
        let isCritical = supported.contains { $0.isCritical }
        var offer = candidate
        offer.isCritical = isCritical
        if isCritical { return .available(offer) }

        if let skippedVersion, candidate.version <= skippedVersion {
            return .skipped(offer)
        }
        if let remindAfter, now < remindAfter {
            return .postponed(offer, until: remindAfter)
        }
        return .available(offer)
    }
}
