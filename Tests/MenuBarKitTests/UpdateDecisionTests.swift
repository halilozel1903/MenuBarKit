import Foundation
import Testing
@testable import MenuBarKit

@Suite("Update feed and decision")
struct UpdateDecisionTests {
    let url = URL(string: "https://example.com/Tempo.dmg")!
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    func release(_ version: SemanticVersion, minimumSystem: SemanticVersion? = nil, critical: Bool = false) -> UpdateRelease {
        UpdateRelease(version: version, downloadURL: url, notes: ["Notes for \(version)"], minimumSystemVersion: minimumSystem, isCritical: critical)
    }

    @Test func decodesFeedWithReleases() throws {
        let json = """
        {
          "releases": [
            { "version": "1.3.0", "url": "https://example.com/Tempo-1.3.0.dmg",
              "notes": ["Focus statistics", "Faster launch"], "minimumSystemVersion": "14.0", "critical": false },
            { "version": "1.2.1", "url": "https://example.com/Tempo-1.2.1.dmg", "notes": "Fixes a crash\\n\\nSmaller download" }
          ]
        }
        """
        let feed = try UpdateFeed.decode(Data(json.utf8))
        #expect(feed.releases.count == 2)
        #expect(feed.releases[0].version == "1.3.0")
        #expect(feed.releases[0].notes == ["Focus statistics", "Faster launch"])
        #expect(feed.releases[0].minimumSystemVersion == "14.0")
        #expect(feed.releases[1].notes == ["Fixes a crash", "Smaller download"])
        #expect(feed.releases[1].isCritical == false)
        #expect(feed.releases[1].downloadURL.absoluteString == "https://example.com/Tempo-1.2.1.dmg")
    }

    @Test func decodesSingleReleaseFeed() throws {
        let json = #"{ "version": "v2.0", "url": "https://example.com/Tempo.zip", "critical": true }"#
        let feed = try UpdateFeed.decode(Data(json.utf8))
        #expect(feed.releases.count == 1)
        #expect(feed.releases[0].version == "2.0")
        #expect(feed.releases[0].notes.isEmpty)
        #expect(feed.releases[0].isCritical)
    }

    @Test func rejectsInvalidFeeds() {
        #expect(throws: (any Error).self) { try UpdateFeed.decode(Data(#"{"version":"soon","url":"https://example.com"}"#.utf8)) }
        #expect(throws: (any Error).self) { try UpdateFeed.decode(Data(#"{"releases":[{"version":"1.0"}]}"#.utf8)) }
        #expect(throws: (any Error).self) { try UpdateFeed.decode(Data("not json".utf8)) }
    }

    @Test func feedRoundTrips() throws {
        let feed = UpdateFeed(releases: [release("1.3"), release("1.4", minimumSystem: "15.0", critical: true)])
        let data = try JSONEncoder().encode(feed)
        #expect(try UpdateFeed.decode(data) == feed)
    }

    @Test func upToDateWhenNothingIsNewer() {
        let feed = UpdateFeed(releases: [release("1.1"), release("1.2")])
        let decision = UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", now: now)
        #expect(decision == .upToDate)
        #expect(!decision.shouldPrompt)
        #expect(decision.release == nil)
        #expect(UpdatePolicy().decide(current: "1.2", feed: UpdateFeed(releases: []), system: "26.0", now: now) == .upToDate)
    }

    @Test func offersTheNewestRelease() {
        let feed = UpdateFeed(releases: [release("1.2.1"), release("1.4"), release("1.3")])
        let decision = UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", now: now)
        #expect(decision == .available(release("1.4")))
        #expect(decision.shouldPrompt)
    }

    @Test func comparesVersionsNumerically() {
        let feed = UpdateFeed(releases: [release("1.10")])
        #expect(UpdatePolicy().decide(current: "1.9", feed: feed, system: "26.0", now: now).shouldPrompt)
    }

    @Test func ignoresPrereleasesUnlessAsked() {
        let feed = UpdateFeed(releases: [release("1.3"), release("2.0.0-beta.1")])
        #expect(UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", now: now) == .available(release("1.3")))
        let beta = UpdatePolicy(includesPrereleases: true).decide(current: "1.2", feed: feed, system: "26.0", now: now)
        #expect(beta == .available(release("2.0.0-beta.1")))
        // A beta of the running release is older than the release itself.
        #expect(UpdatePolicy(includesPrereleases: true).decide(current: "1.3", feed: UpdateFeed(releases: [release("1.3.0-rc.1")]), system: "26.0", now: now) == .upToDate)
    }

    @Test func respectsMinimumSystemVersion() {
        let feed = UpdateFeed(releases: [release("1.3", minimumSystem: "14.0"), release("2.0", minimumSystem: "26.0")])
        #expect(UpdatePolicy().decide(current: "1.2", feed: feed, system: "15.6", now: now) == .available(release("1.3", minimumSystem: "14.0")))
        #expect(UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", now: now) == .available(release("2.0", minimumSystem: "26.0")))
        #expect(UpdatePolicy().decide(current: "1.3", feed: feed, system: "15.6", now: now) == .requiresNewerSystem(release("2.0", minimumSystem: "26.0")))
    }

    @Test func skippedVersionIsNotOfferedAgain() {
        let feed = UpdateFeed(releases: [release("1.3")])
        #expect(UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", skippedVersion: "1.3", now: now) == .skipped(release("1.3")))
        // A newer release than the skipped one is offered.
        let newer = UpdateFeed(releases: [release("1.3"), release("1.4")])
        #expect(UpdatePolicy().decide(current: "1.2", feed: newer, system: "26.0", skippedVersion: "1.3", now: now) == .available(release("1.4")))
    }

    @Test func remindLaterPostponesUntilTheDate() {
        let feed = UpdateFeed(releases: [release("1.3")])
        let later = now.addingTimeInterval(3600)
        #expect(UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", remindAfter: later, now: now) == .postponed(release("1.3"), until: later))
        #expect(UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", remindAfter: later, now: later.addingTimeInterval(1)) == .available(release("1.3")))
    }

    @Test func criticalReleaseIgnoresSkipAndReminder() {
        let feed = UpdateFeed(releases: [release("1.3", critical: true)])
        let decision = UpdatePolicy().decide(
            current: "1.2", feed: feed, system: "26.0",
            skippedVersion: "1.3", remindAfter: now.addingTimeInterval(3600), now: now
        )
        #expect(decision == .available(release("1.3", critical: true)))
    }

    @Test func criticalFixInBetweenMakesTheOfferCritical() throws {
        let feed = UpdateFeed(releases: [release("1.2.1", critical: true), release("1.3")])
        let decision = UpdatePolicy().decide(current: "1.2", feed: feed, system: "26.0", skippedVersion: "1.3", now: now)
        let offered = try #require(decision.release)
        #expect(decision.shouldPrompt)
        #expect(offered.version == "1.3")
        #expect(offered.isCritical)
    }
}

@Suite("UpdateChecker")
@MainActor
struct UpdateCheckerTests {
    let feed = #"{"releases":[{"version":"1.3.0","url":"https://example.com/Tempo.dmg","notes":["Focus statistics"]}]}"#

    func makeDefaults() -> UserDefaults {
        let name = "MenuBarKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func findsAnUpdate() async {
        let checker = UpdateChecker(
            feedURL: URL(string: "https://example.com/feed.json")!,
            currentVersion: "1.2",
            loader: StaticFeedLoader(json: feed),
            defaults: makeDefaults(),
            systemVersion: "26.0"
        )
        let decision = await checker.checkForUpdates()
        #expect(decision?.shouldPrompt == true)
        #expect(checker.availableRelease?.version == "1.3")
    }

    @Test func skipAndRemindLaterArePersisted() async throws {
        let defaults = makeDefaults()
        let checker = UpdateChecker(
            feedURL: URL(string: "https://example.com/feed.json")!,
            currentVersion: "1.2",
            loader: StaticFeedLoader(json: feed),
            defaults: defaults,
            systemVersion: "26.0"
        )
        await checker.checkForUpdates()
        let release = try #require(checker.availableRelease)

        checker.skip(release)
        #expect(checker.availableRelease == nil)
        #expect(checker.skippedVersion == "1.3")
        let skipped = await checker.checkForUpdates()
        #expect(skipped == .skipped(release))
        #expect(checker.availableRelease == nil)

        // "Check for Updates…" from a menu ignores the skip.
        let manual = await checker.checkForUpdates(userInitiated: true)
        #expect(manual?.shouldPrompt == true)

        checker.reset()
        let now = Date()
        checker.remindLater(release, now: now)
        let remindAfter = try #require(checker.remindAfter)
        #expect(abs(remindAfter.timeIntervalSince(now) - 24 * 60 * 60) < 0.01)
        let postponed = await checker.checkForUpdates(now: now.addingTimeInterval(60))
        #expect(postponed?.shouldPrompt == false)
    }

    @Test func reportsBrokenFeeds() async {
        let checker = UpdateChecker(
            feedURL: URL(string: "https://example.com/feed.json")!,
            currentVersion: "1.2",
            loader: StaticFeedLoader(json: "<html>"),
            defaults: makeDefaults(),
            systemVersion: "26.0"
        )
        let decision = await checker.checkForUpdates()
        #expect(decision == nil)
        if case .failed = checker.state {} else {
            Issue.record("Expected a failed state, got \(checker.state)")
        }
    }
}
