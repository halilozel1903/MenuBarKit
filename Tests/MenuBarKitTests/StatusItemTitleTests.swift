import Testing
@testable import MenuBarKit

@Suite("Status item title formatting")
struct StatusItemTitleTests {
    @Test func counts() {
        #expect(StatusItemTitle.count(0) == "")
        #expect(StatusItemTitle.count(-4) == "")
        #expect(StatusItemTitle.count(1) == "1")
        #expect(StatusItemTitle.count(99) == "99")
        #expect(StatusItemTitle.count(100) == "99+")
        #expect(StatusItemTitle.count(12, limit: 9) == "9+")
        #expect(StatusItemTitle.count(3, limit: 0) == "1+")
    }

    @Test(arguments: [
        (0.0, "0:00"),
        (-12.0, "0:00"),
        (0.2, "0:01"),
        (5.0, "0:05"),
        (65.0, "1:05"),
        (1_453.0, "24:13"),
        (1_500.0, "25:00"),
        (3_599.4, "1:00:00"),
        (3_600.0, "1:00:00"),
        (3_723.0, "1:02:03"),
        (.infinity, "0:00"),
        (.nan, "0:00"),
    ])
    func countdown(seconds: Double, expected: String) {
        #expect(StatusItemTitle.countdown(seconds) == expected)
    }

    @Test func percentages() {
        #expect(StatusItemTitle.percent(0.423) == "42%")
        #expect(StatusItemTitle.percent(1.7) == "100%")
        #expect(StatusItemTitle.percent(-1) == "0%")
        #expect(StatusItemTitle.percent(.nan) == "0%")
    }

    @Test func truncation() {
        #expect(StatusItemTitle.truncated("Deploying production", maxLength: 12) == "Deploying p…")
        #expect(StatusItemTitle.truncated("Deploying production", maxLength: 11) == "Deploying…")
        #expect(StatusItemTitle.truncated("  Short  ", maxLength: 12) == "Short")
        #expect(StatusItemTitle.truncated("Line one\nline   two", maxLength: 40) == "Line one line two")
        #expect(StatusItemTitle.truncated("Hello", maxLength: 5) == "Hello")
        #expect(StatusItemTitle.truncated("Hello", maxLength: 1) == "…")
        #expect(StatusItemTitle.truncated("Hello", maxLength: 0) == "")
    }

    @Test func joining() {
        #expect(StatusItemTitle.join(["24:13", nil, "", " ", "3"]) == "24:13 · 3")
        #expect(StatusItemTitle.join([nil, ""]) == "")
        #expect(StatusItemTitle.join(["A", "B"], separator: " ") == "A B")
    }
}
