// ConsumerUsageTests.swift
// Notification Intelligence Engine - Swift Tests
//
// Consumer validation tests demonstrating real-world usage patterns.
// These tests prove NIE is usable in production scheduling contexts
// WITHOUT any coupling to specific application code.

import XCTest
@testable import NotificationIntelligence

/// Simulates a scheduling application's shift model.
/// This is a hypothetical consumer type - NOT imported from any app.
private struct WorkShift {
    let shiftId: String
    let employeeName: String
    let department: String
    let startTime: Date
    let endTime: Date
    let location: String
}

/// Simulates a notification payload that a consumer app would create.
private struct NotificationPayload {
    let title: String
    let body: String
    let scheduledTime: Date
    let userInfo: [String: String]
}

final class ConsumerUsageTests: XCTestCase {

    // MARK: - Test: Shift to Event Mapping

    /// Demonstrates mapping application-specific shift data to NIEvent.
    func testShiftToEventMapping() {
        // Simulated shift from a scheduling system
        let shift = WorkShift(
            shiftId: "shift-2024-001",
            employeeName: "John Doe",
            department: "Emergency",
            startTime: Date(timeIntervalSince1970: 1710504000), // 2024-03-15T10:00:00Z
            endTime: Date(timeIntervalSince1970: 1710532800),   // 2024-03-15T18:00:00Z
            location: "Building A"
        )

        // Map to NIEvent - the consumer's responsibility
        let event = NIEvent(
            id: shift.shiftId,
            startTime: shift.startTime,
            endTime: shift.endTime,
            label: "\(shift.department) Shift",
            metadata: [
                "employee": AnyCodable(shift.employeeName),
                "location": AnyCodable(shift.location)
            ]
        )

        // Verify mapping
        XCTAssertEqual(event.id, "shift-2024-001")
        XCTAssertEqual(event.label, "Emergency Shift")
        XCTAssertNotNil(event.endTime)
    }

    // MARK: - Test: End-to-End Resolution

    /// Demonstrates complete flow: shifts → events → resolution → notification payload.
    func testEndToEndResolution() {
        // Reference time: 2024-03-15 at 08:00 local time
        let referenceTime = Date(timeIntervalSince1970: 1710496800) // 2024-03-15T08:00:00Z

        // Simulated shifts from a scheduling system
        let shifts = [
            WorkShift(
                shiftId: "morning-shift",
                employeeName: "Alice",
                department: "Radiology",
                startTime: Date(timeIntervalSince1970: 1710504000), // 10:00
                endTime: Date(timeIntervalSince1970: 1710532800),   // 18:00
                location: "Wing B"
            ),
            WorkShift(
                shiftId: "evening-shift",
                employeeName: "Bob",
                department: "ICU",
                startTime: Date(timeIntervalSince1970: 1710532800), // 18:00
                endTime: Date(timeIntervalSince1970: 1710561600),   // 02:00 next day
                location: "Wing A"
            )
        ]

        // Consumer maps shifts to events
        let events: [NIEvent] = shifts.map { shift in
            NIEvent(
                id: shift.shiftId,
                startTime: shift.startTime,
                endTime: shift.endTime,
                label: "\(shift.department) - \(shift.employeeName)"
            )
        }

        // Configure resolver with 30-minute lead time
        let config = NIResolverConfig(
            timezone: TimeZone(identifier: "UTC")!,
            triggerLeadTimeMinutes: 30
        )

        // Resolve upcoming event
        let result = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: events,
            config: config
        )

        // Verify resolution
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.event.id, "morning-shift")
        XCTAssertEqual(result?.dayLabel, .today)

        // Consumer builds notification payload from result
        if let info = result {
            let payload = NotificationPayload(
                title: "Upcoming Shift",
                body: info.event.label ?? "Shift starting soon",
                scheduledTime: info.triggerTime,
                userInfo: ["eventId": info.event.id]
            )

            // Verify payload construction
            XCTAssertEqual(payload.title, "Upcoming Shift")
            XCTAssertEqual(payload.body, "Radiology - Alice")
            XCTAssertEqual(payload.userInfo["eventId"], "morning-shift")

            // Trigger time should be 30 minutes before start
            let expectedTrigger = info.startTime.addingTimeInterval(-30 * 60)
            XCTAssertEqual(payload.scheduledTime.timeIntervalSince1970,
                          expectedTrigger.timeIntervalSince1970,
                          accuracy: 1.0)
        }
    }

    // MARK: - Test: Skip Predicate Usage

    /// Demonstrates using skipPredicate to filter out specific events.
    func testSkipPredicateUsage() {
        let referenceTime = Date(timeIntervalSince1970: 1710496800)

        let events = [
            NIEvent(id: "cancelled-shift", startTime: Date(timeIntervalSince1970: 1710504000), label: "Cancelled"),
            NIEvent(id: "active-shift", startTime: Date(timeIntervalSince1970: 1710507600), label: "Active")
        ]

        // Consumer provides skip logic (e.g., skip cancelled shifts)
        let cancelledIds: Set<String> = ["cancelled-shift"]

        let config = NIResolverConfig(
            timezone: TimeZone(identifier: "UTC")!,
            skipPredicate: { event in
                cancelledIds.contains(event.id)
            }
        )

        let result = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: events,
            config: config
        )

        // Should skip cancelled shift and return active shift
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.event.id, "active-shift")
    }

    // MARK: - Test: Timezone Handling

    /// Demonstrates proper timezone handling for international deployments.
    func testTimezoneHandling() {
        // Reference: 2024-03-15 at 23:00 in Tokyo (which is 14:00 UTC)
        let referenceTime = Date(timeIntervalSince1970: 1710511200) // 14:00 UTC

        // Event at 01:00 Tokyo time next day (16:00 UTC same day)
        let events = [
            NIEvent(
                id: "night-shift",
                startTime: Date(timeIntervalSince1970: 1710518400), // 16:00 UTC = 01:00+1 Tokyo
                label: "Night Shift"
            )
        ]

        let tokyoConfig = NIResolverConfig(
            timezone: TimeZone(identifier: "Asia/Tokyo")!,
            triggerLeadTimeMinutes: 60
        )

        let result = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: events,
            config: tokyoConfig
        )

        XCTAssertNotNil(result)
        // Event is tomorrow in Tokyo timezone (crosses midnight)
        XCTAssertEqual(result?.dayLabel, .tomorrow)
    }

    // MARK: - Test: Empty Events Handling

    /// Demonstrates graceful handling when no events are available.
    func testEmptyEventsHandling() {
        let referenceTime = Date()
        let events: [NIEvent] = []

        let config = NIResolverConfig(
            timezone: TimeZone.current
        )

        let result = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: events,
            config: config
        )

        // Should return nil gracefully
        XCTAssertNil(result)
    }

    // MARK: - Test: Multiple Day Labels

    /// Demonstrates all day label possibilities.
    func testDayLabelVariations() {
        // Reference: morning of 2024-03-15
        let referenceTime = Date(timeIntervalSince1970: 1710489600) // 06:00 UTC

        let config = NIResolverConfig(
            timezone: TimeZone(identifier: "UTC")!
        )

        // Today event
        let todayEvents = [
            NIEvent(id: "today", startTime: Date(timeIntervalSince1970: 1710504000)) // 10:00 same day
        ]
        let todayResult = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: todayEvents,
            config: config
        )
        XCTAssertEqual(todayResult?.dayLabel, .today)

        // Tomorrow event
        let tomorrowEvents = [
            NIEvent(id: "tomorrow", startTime: Date(timeIntervalSince1970: 1710590400)) // 10:00 next day
        ]
        let tomorrowResult = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: tomorrowEvents,
            config: config
        )
        XCTAssertEqual(tomorrowResult?.dayLabel, .tomorrow)

        // Later event (3 days out)
        let laterEvents = [
            NIEvent(id: "later", startTime: Date(timeIntervalSince1970: 1710763200)) // 10:00 in 3 days
        ]
        let laterResult = NIResolver.resolveUpcomingEvent(
            referenceTime: referenceTime,
            events: laterEvents,
            config: config
        )
        XCTAssertEqual(laterResult?.dayLabel, .later)
    }
}
