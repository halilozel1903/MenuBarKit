import AppKit
import Combine
import Foundation

/// Loads the raw bytes of an update feed. ``URLSessionFeedLoader`` is the default; tests and
/// previews return fixed JSON.
public protocol UpdateFeedLoading: Sendable {
    func loadFeed(from url: URL) async throws -> Data
}

/// Downloads the feed with `URLSession`, ignoring caches so a new release shows up right away.
public struct URLSessionFeedLoader: UpdateFeedLoading {
    public enum LoadError: Error, Sendable, Equatable {
        case httpStatus(Int)
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func loadFeed(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LoadError.httpStatus(http.statusCode)
        }
        return data
    }
}

/// A feed loader that returns fixed data, for previews, tests and offline demos.
public struct StaticFeedLoader: UpdateFeedLoading {
    private let data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(json: String) {
        self.data = Data(json.utf8)
    }

    public func loadFeed(from url: URL) async throws -> Data {
        data
    }
}

/// Checks a JSON feed for a newer version and remembers the user's "Skip" and "Remind Me Later".
///
/// ```swift
/// @StateObject private var updates = UpdateChecker(feedURL: URL(string: "https://example.com/tempo.json")!)
///
/// MenuBarPanel(...) {
///     UpdateBanner(checker: updates)
///     ...
/// }
/// .task { await updates.checkForUpdates() }
/// ```
///
/// The feed format and the rules are described in ``UpdateFeed`` and ``UpdatePolicy``.
@MainActor
public final class UpdateChecker: ObservableObject {
    public enum State: Sendable, Equatable {
        case idle
        case checking
        case finished(UpdateDecision)
        case failed(String)
    }

    /// The result of the last check.
    @Published public private(set) var state: State = .idle
    /// The release to offer. Set by a check that finds one, cleared by ``download(_:)``,
    /// ``skip(_:)`` and ``remindLater(_:)``.
    @Published public var availableRelease: UpdateRelease?

    public let feedURL: URL
    public let currentVersion: SemanticVersion
    public var policy: UpdatePolicy
    /// How long "Remind Me Later" waits. One day by default.
    public var remindInterval: TimeInterval

    private let loader: any UpdateFeedLoading
    private let defaults: UserDefaults
    private let systemVersion: SemanticVersion

    /// - Parameters:
    ///   - feedURL: The JSON feed.
    ///   - currentVersion: The running version; the app's `CFBundleShortVersionString` by default.
    ///   - policy: Whether pre-releases are offered.
    ///   - remindInterval: How long "Remind Me Later" waits.
    ///   - loader: How the feed is downloaded.
    ///   - defaults: Where the skipped version and the reminder date are kept.
    ///   - systemVersion: The macOS version releases are checked against.
    public init(
        feedURL: URL,
        currentVersion: SemanticVersion? = nil,
        policy: UpdatePolicy = UpdatePolicy(),
        remindInterval: TimeInterval = 24 * 60 * 60,
        loader: any UpdateFeedLoading = URLSessionFeedLoader(),
        defaults: UserDefaults = .standard,
        systemVersion: SemanticVersion = .operatingSystem
    ) {
        self.feedURL = feedURL
        self.currentVersion = currentVersion ?? SemanticVersion.current ?? SemanticVersion(0)
        self.policy = policy
        self.remindInterval = remindInterval
        self.loader = loader
        self.defaults = defaults
        self.systemVersion = systemVersion
    }

    /// The version the user chose to skip.
    public var skippedVersion: SemanticVersion? {
        defaults.string(forKey: Keys.skippedVersion).flatMap { SemanticVersion($0) }
    }

    /// When "Remind Me Later" ends.
    public var remindAfter: Date? {
        defaults.object(forKey: Keys.remindAfter) as? Date
    }

    /// Downloads the feed and decides.
    ///
    /// - Parameter userInitiated: `true` for a "Check for Updates…" command. It ignores a skipped
    ///   version and a pending reminder, because the user asked.
    @discardableResult
    public func checkForUpdates(userInitiated: Bool = false, now: Date = Date()) async -> UpdateDecision? {
        guard state != .checking else { return nil }
        state = .checking
        do {
            let data = try await loader.loadFeed(from: feedURL)
            let feed = try UpdateFeed.decode(data)
            let decision = policy.decide(
                current: currentVersion,
                feed: feed,
                system: systemVersion,
                skippedVersion: userInitiated ? nil : skippedVersion,
                remindAfter: userInitiated ? nil : remindAfter,
                now: now
            )
            state = .finished(decision)
            availableRelease = decision.shouldPrompt ? decision.release : nil
            return decision
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Opens the release's download link and hides the prompt.
    public func download(_ release: UpdateRelease) {
        NSWorkspace.shared.open(release.downloadURL)
        availableRelease = nil
    }

    /// Never offers this version again. A newer one, or a critical one, is still offered.
    public func skip(_ release: UpdateRelease) {
        defaults.set(release.version.description, forKey: Keys.skippedVersion)
        availableRelease = nil
    }

    /// Hides the prompt until ``remindInterval`` has passed.
    public func remindLater(_ release: UpdateRelease, now: Date = Date()) {
        defaults.set(now.addingTimeInterval(remindInterval), forKey: Keys.remindAfter)
        availableRelease = nil
    }

    /// Forgets the skipped version and the reminder, for a debug menu.
    public func reset() {
        defaults.removeObject(forKey: Keys.skippedVersion)
        defaults.removeObject(forKey: Keys.remindAfter)
        availableRelease = nil
        state = .idle
    }

    private enum Keys {
        static let skippedVersion = "MenuBarKit.update.skippedVersion"
        static let remindAfter = "MenuBarKit.update.remindAfter"
    }
}
