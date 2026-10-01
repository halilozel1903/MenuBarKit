import Foundation
import MenuBarKit

/// Made-up data for the example app, so it works offline and every screenshot is the same.
enum DemoContent {
    /// The update feed the demo "downloads". A real app points ``UpdateChecker`` at a JSON file on its website.
    static let feedURL = URL(string: "https://example.com/tempo/releases.json")!

    static let feedJSON = """
    {
      "releases": [
        {
          "version": "1.3.0",
          "url": "https://github.com/halilozel1903/MenuBarKit/releases",
          "notes": [
            "Focus statistics for the last 7 days",
            "Long breaks after every fourth session",
            "The timer keeps running while the Mac sleeps",
            "Faster launch and lower energy use"
          ],
          "minimumSystemVersion": "14.0"
        },
        {
          "version": "1.2.1",
          "url": "https://github.com/halilozel1903/MenuBarKit/releases",
          "notes": ["Fixes the timer skipping a second"]
        }
      ]
    }
    """

    /// The release shown in the update screenshot.
    static var release: UpdateRelease {
        (try? UpdateFeed.decode(Data(feedJSON.utf8)).releases.first) ?? UpdateRelease(
            version: "1.3.0",
            downloadURL: URL(string: "https://github.com/halilozel1903/MenuBarKit/releases")!
        )
    }

    static let about = AboutInfo.fromBundle(
        tagline: "A calm focus timer that lives in your menu bar.",
        links: [
            AboutInfo.Link("Website", url: URL(string: "https://github.com/halilozel1903/MenuBarKit")!),
            AboutInfo.Link("Source Code", url: URL(string: "https://github.com/halilozel1903/MenuBarKit")!),
        ]
    )
}
