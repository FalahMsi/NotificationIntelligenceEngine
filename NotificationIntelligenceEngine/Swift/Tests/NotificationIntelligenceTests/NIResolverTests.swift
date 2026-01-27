// NIResolverTests.swift
// Notification Intelligence Engine - Swift Tests
//
// Tests for the NIResolver using the shared test vectors.

import XCTest
@testable import NotificationIntelligence

final class NIResolverTests: XCTestCase {

    private var testVectors: [TestVector] = []

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Load test vectors from the JSON file
        guard let url = Bundle.module.url(forResource: "test-vectors", withExtension: "json") else {
            XCTFail("Could not find test-vectors.json in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let file = try decoder.decode(TestVectorFile.self, from: data)
        testVectors = file.vectors
    }

    func testAllVectors() throws {
        XCTAssertFalse(testVectors.isEmpty, "No test vectors loaded")

        for vector in testVectors {
            try runTestVector(vector)
        }
    }

    private func runTestVector(_ vector: TestVector) throws {
        // Parse reference time
        let referenceTime = try parseISO8601(vector.referenceTimeISO)

        // Parse events
        let events: [NIEvent] = try vector.events.map { testEvent in
            let startTime = try parseISO8601(testEvent.startTimeISO)
            let endTime = testEvent.endTimeISO.flatMap { try? parseISO8601($0) }
            return NIEvent(
                id: testEvent.id,
                startTime: startTime,
                endTime: endTime
            )
        }

        // Get timezone
        guard let timezone = TimeZone(identifier: vector.timezone) else {
            XCTFail("[\(vector.id)] Invalid timezone: \(vector.timezone)")
            return
        }

        // Create skip predicate based on skipEventIds
        let skipSet = Set(vector.skipEventIds)
        let skipPredicate: ((NIEvent) -> Bool)? = skipSet.isEmpty ? nil : { event in
            skipSet.contains(event.id)
        }

        // Create config
        let config = NIResolverConfig(
            timezone: timezone,
            lookaheadDays: vector.lookaheadDays,
            triggerLeadTimeMinutes: vector.triggerLeadTimeMinutes,
            skipPredicate: skipPredicate
        )

        // Run resolver
        let result = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: events,
            config: config
        )

        // Validate result
        if let expectedEventId = vector.expected.expectedEventId {
            // Should have a result
            XCTAssertNotNil(result, "[\(vector.id)] Expected event \(expectedEventId) but got nil")

            guard let result = result else { return }

            // Check event ID
            XCTAssertEqual(
                result.event.id,
                expectedEventId,
                "[\(vector.id)] Event ID mismatch"
            )

            // Check day label
            if let expectedDayLabel = vector.expected.expectedDayLabel {
                XCTAssertEqual(
                    result.dayLabel.rawValue,
                    expectedDayLabel,
                    "[\(vector.id)] Day label mismatch"
                )
            }

            // Check trigger time
            if let expectedTriggerTimeISO = vector.expected.expectedTriggerTimeISO {
                let expectedTriggerTime = try parseISO8601(expectedTriggerTimeISO)
                XCTAssertEqual(
                    result.triggerTime.timeIntervalSince1970,
                    expectedTriggerTime.timeIntervalSince1970,
                    accuracy: 1.0,
                    "[\(vector.id)] Trigger time mismatch"
                )
            }

            // Check end time if expected
            if let expectedEndTimeISO = vector.expected.expectedEndTimeISO {
                let expectedEndTime = try parseISO8601(expectedEndTimeISO)
                XCTAssertNotNil(result.endTime, "[\(vector.id)] Expected end time but got nil")
                if let endTime = result.endTime {
                    XCTAssertEqual(
                        endTime.timeIntervalSince1970,
                        expectedEndTime.timeIntervalSince1970,
                        accuracy: 1.0,
                        "[\(vector.id)] End time mismatch"
                    )
                }
            }
        } else {
            // Should be nil
            XCTAssertNil(result, "[\(vector.id)] Expected nil but got event \(result?.event.id ?? "unknown")")
        }
    }

    private func parseISO8601(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withColonSeparatorInTimeZone
        ]

        if let date = formatter.date(from: string) {
            return date
        }

        // Try without colon in timezone (e.g., +0000 instead of +00:00)
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }

        throw NSError(
            domain: "TestVector",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not parse date: \(string)"]
        )
    }
}
