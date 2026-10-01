import Foundation
import Testing
@testable import MenuBarKit

@Suite("SemanticVersion parsing and comparison")
struct SemanticVersionTests {
    @Test(arguments: [
        ("1", SemanticVersion(1, 0, 0)),
        ("1.2", SemanticVersion(1, 2, 0)),
        ("1.2.3", SemanticVersion(1, 2, 3)),
        ("v2.0", SemanticVersion(2, 0, 0)),
        ("V10.4.1", SemanticVersion(10, 4, 1)),
        ("  3.1  ", SemanticVersion(3, 1, 0)),
        ("2.1.0+482", SemanticVersion(2, 1, 0)),
        ("1.0.0-beta.2", SemanticVersion(1, 0, 0, prerelease: ["beta", "2"])),
        ("4.0-rc-1+build.7", SemanticVersion(4, 0, 0, prerelease: ["rc-1"])),
    ])
    func parsesValidVersions(input: String, expected: SemanticVersion) {
        #expect(SemanticVersion(input) == expected)
    }

    @Test(arguments: ["", " ", "v", "a.b", "1..2", "1.2.", ".1", "1.2.3.4", "-1", "1.-2", "1.2-", "1.2-beta..1", "1,2", "1.x"])
    func rejectsInvalidVersions(input: String) {
        #expect(SemanticVersion(input) == nil)
    }

    @Test func descriptions() {
        #expect(SemanticVersion(1, 2).description == "1.2.0")
        #expect(SemanticVersion(1, 2).shortDescription == "1.2")
        #expect(SemanticVersion(1, 2, 3).shortDescription == "1.2.3")
        #expect(SemanticVersion(2, 0, 0, prerelease: ["beta", "1"]).description == "2.0.0-beta.1")
        #expect(SemanticVersion(2, 0, 0, prerelease: ["beta", "1"]).shortDescription == "2.0.0-beta.1")
    }

    @Test func numericComparisonNotLexical() {
        #expect(SemanticVersion(1, 10) > SemanticVersion(1, 9))
        #expect(SemanticVersion(2, 0, 0) > SemanticVersion(1, 99, 99))
        #expect(SemanticVersion(1, 2, 10) > SemanticVersion(1, 2, 9))
        #expect(SemanticVersion(1, 2) == SemanticVersion("1.2.0"))
        let literal: SemanticVersion = "1.10"
        #expect(literal > "1.9")
    }

    /// The precedence example from the Semantic Versioning specification, item 11.
    @Test func prereleasePrecedenceFollowsSemver() throws {
        let strings = [
            "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
            "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0",
        ]
        let ordered = strings.compactMap { SemanticVersion($0) }
        try #require(ordered.count == strings.count)
        for (lower, higher) in zip(ordered, ordered.dropFirst()) {
            #expect(lower < higher, "\(lower) should come before \(higher)")
        }
        let shuffled = ordered.reversed().sorted()
        #expect(shuffled == ordered)
    }

    @Test func codableAsString() throws {
        let data = try JSONEncoder().encode(["version": SemanticVersion(1, 3, 0, prerelease: ["rc", "1"])])
        #expect(String(decoding: data, as: UTF8.self) == #"{"version":"1.3.0-rc.1"}"#)
        let decoded = try JSONDecoder().decode([String: SemanticVersion].self, from: data)
        #expect(decoded["version"] == SemanticVersion(1, 3, 0, prerelease: ["rc", "1"]))
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([String: SemanticVersion].self, from: Data(#"{"version":"one"}"#.utf8))
        }
    }
}
