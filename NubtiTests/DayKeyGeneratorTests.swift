import XCTest
@testable import Nubti

/// DayKeyGeneratorTests
/// Unit tests for the DayKeyGenerator utility.
///
/// These tests verify:
/// 1. Canonical format (YYYY-MM-DD with zero-padding)
/// 2. Legacy format detection and canonicalization
/// 3. Timezone consistency
final class DayKeyGeneratorTests: XCTestCase {

    // MARK: - Test Setup

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuwait")!
    }

    override func tearDown() {
        calendar = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    // MARK: - Canonical Format Tests

    /// Test that single-digit months are zero-padded
    func testSingleDigitMonthZeroPadded() {
        let date = makeDate(year: 2026, month: 1, day: 15)
        let key = DayKeyGenerator.key(for: date, calendar: calendar)

        XCTAssertEqual(key, "2026-01-15", "Month should be zero-padded")
        XCTAssertFalse(key.contains("-1-"), "Should not contain single-digit month")
    }

    /// Test that single-digit days are zero-padded
    func testSingleDigitDayZeroPadded() {
        let date = makeDate(year: 2026, month: 12, day: 5)
        let key = DayKeyGenerator.key(for: date, calendar: calendar)

        XCTAssertEqual(key, "2026-12-05", "Day should be zero-padded")
        XCTAssertFalse(key.contains("-5"), "Should not end with single-digit day")
    }

    /// Test both month and day zero-padded
    func testBothMonthAndDayZeroPadded() {
        let date = makeDate(year: 2026, month: 3, day: 7)
        let key = DayKeyGenerator.key(for: date, calendar: calendar)

        XCTAssertEqual(key, "2026-03-07", "Both month and day should be zero-padded")
    }

    /// Test double-digit month and day (no padding needed)
    func testDoubleDigitNoExtraPadding() {
        let date = makeDate(year: 2026, month: 11, day: 25)
        let key = DayKeyGenerator.key(for: date, calendar: calendar)

        XCTAssertEqual(key, "2026-11-25", "Double-digit values should not have extra padding")
    }

    // MARK: - Legacy Format Tests

    /// Test that legacy format without zero-padding is detected
    func testLegacyFormatDetection() {
        XCTAssertTrue(DayKeyGenerator.isLegacyFormat("2026-1-5"), "Should detect legacy format")
        XCTAssertTrue(DayKeyGenerator.isLegacyFormat("2026-1-15"), "Should detect legacy month")
        XCTAssertTrue(DayKeyGenerator.isLegacyFormat("2026-12-5"), "Should detect legacy day")
        XCTAssertFalse(DayKeyGenerator.isLegacyFormat("2026-01-05"), "Should not flag canonical format")
    }

    /// Test canonicalization of legacy format
    func testCanonicalizeLegacyFormat() {
        XCTAssertEqual(DayKeyGenerator.canonicalize("2026-1-5"), "2026-01-05")
        XCTAssertEqual(DayKeyGenerator.canonicalize("2026-1-15"), "2026-01-15")
        XCTAssertEqual(DayKeyGenerator.canonicalize("2026-12-5"), "2026-12-05")
        XCTAssertEqual(DayKeyGenerator.canonicalize("2026-01-05"), "2026-01-05")
    }

    // MARK: - Timezone Consistency Tests

    /// Test that the same date produces the same key regardless of time
    func testSameDateDifferentTimes() {
        var morningComponents = DateComponents()
        morningComponents.year = 2026
        morningComponents.month = 2
        morningComponents.day = 25
        morningComponents.hour = 6
        morningComponents.timeZone = calendar.timeZone
        let morningDate = calendar.date(from: morningComponents)!

        var eveningComponents = morningComponents
        eveningComponents.hour = 22
        let eveningDate = calendar.date(from: eveningComponents)!

        let morningKey = DayKeyGenerator.key(for: morningDate, calendar: calendar)
        let eveningKey = DayKeyGenerator.key(for: eveningDate, calendar: calendar)

        XCTAssertEqual(morningKey, eveningKey, "Same date should produce same key regardless of time")
        XCTAssertEqual(morningKey, "2026-02-25")
    }

    /// Test that different timezones produce correct keys
    func testDifferentTimezones() {
        // Create a date in UTC
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 27
        components.hour = 23 // 11 PM UTC = 2 AM Jan 28 in Kuwait (+3)
        components.timeZone = utcCalendar.timeZone
        let utcDate = utcCalendar.date(from: components)!

        let utcKey = DayKeyGenerator.key(for: utcDate, calendar: utcCalendar)
        let kuwaitKey = DayKeyGenerator.key(for: utcDate, calendar: calendar)

        XCTAssertEqual(utcKey, "2026-01-27", "UTC should show Jan 27")
        XCTAssertEqual(kuwaitKey, "2026-01-28", "Kuwait (+3) should show Jan 28")
    }

    // MARK: - Edge Cases

    /// Test year boundary (Dec 31 to Jan 1)
    func testYearBoundary() {
        let dec31 = makeDate(year: 2025, month: 12, day: 31)
        let jan1 = makeDate(year: 2026, month: 1, day: 1)

        XCTAssertEqual(DayKeyGenerator.key(for: dec31, calendar: calendar), "2025-12-31")
        XCTAssertEqual(DayKeyGenerator.key(for: jan1, calendar: calendar), "2026-01-01")
    }

    /// Test leap year Feb 29
    func testLeapYearFeb29() {
        let leapDay = makeDate(year: 2024, month: 2, day: 29)
        XCTAssertEqual(DayKeyGenerator.key(for: leapDay, calendar: calendar), "2024-02-29")
    }
}
