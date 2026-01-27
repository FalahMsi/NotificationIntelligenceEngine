// NIResolver.swift
// Notification Intelligence Engine - Swift
//
// Core resolver implementation for determining the next upcoming event.

import Foundation

/// The main resolver for determining the next upcoming event.
///
/// This resolver implements the semantic contract defined in the NIE specification:
/// 1. Events are selected based on `startTime > referenceTime` (strictly greater)
/// 2. Trigger time is calculated as `startTime - triggerLeadTimeMinutes`
/// 3. Day label is based on comparing trigger time's day to reference time's day
/// 4. Events are filtered by lookahead window and skip predicate
///
/// ## Usage
/// ```swift
/// let result = NIResolver.resolveUpcomingEvent(
///     referenceTime: Date(),
///     events: myEvents,
///     config: myConfig
/// )
/// ```
public enum NIResolver {

    /// Resolves the next upcoming event from a collection of events.
    ///
    /// This function implements the NIE semantic contract:
    /// 1. Filters events to those with `startTime > referenceTime`
    /// 2. Filters events within the lookahead window
    /// 3. Applies the skip predicate (if configured)
    /// 4. Selects the event with the earliest `startTime`
    /// 5. Calculates trigger time and day label
    ///
    /// - Parameters:
    ///   - referenceTime: The reference point in time (typically "now")
    ///   - events: The collection of events to consider
    ///   - config: Configuration for the resolver
    /// - Returns: Information about the next upcoming event, or `nil` if none qualifies
    public static func resolveUpcomingEvent(
        referenceTime: Date,
        events: [NIEvent],
        config: NIResolverConfig
    ) -> NIUpcomingEventInfo? {

        // Calculate the lookahead window end
        let lookaheadEnd = referenceTime.addingTimeInterval(
            TimeInterval(config.lookaheadDays) * 24 * 60 * 60
        )

        // Filter and sort events according to the semantic contract
        let eligibleEvents = events
            // 1. startTime must be strictly greater than referenceTime
            .filter { $0.startTime > referenceTime }
            // 2. startTime must be within lookahead window (inclusive)
            .filter { $0.startTime <= lookaheadEnd }
            // 3. Apply skip predicate if configured
            .filter { event in
                if let skipPredicate = config.skipPredicate {
                    return !skipPredicate(event)
                }
                return true
            }
            // 4. Sort by startTime to get chronological order
            .sorted { $0.startTime < $1.startTime }

        // Select the first (earliest) eligible event
        guard let selectedEvent = eligibleEvents.first else {
            return nil
        }

        // Calculate trigger time: startTime - leadTime
        let triggerTime = selectedEvent.startTime.addingTimeInterval(
            -TimeInterval(config.triggerLeadTimeMinutes) * 60
        )

        // Calculate day label based on trigger time vs reference time
        let dayLabel = calculateDayLabel(
            triggerTime: triggerTime,
            referenceTime: referenceTime,
            timezone: config.timezone
        )

        // Format start time as ISO 8601
        let formattedStartTimeISO = formatISO8601(
            date: selectedEvent.startTime,
            timezone: config.timezone
        )

        return NIUpcomingEventInfo(
            event: selectedEvent,
            startTime: selectedEvent.startTime,
            endTime: selectedEvent.endTime,
            triggerTime: triggerTime,
            dayLabel: dayLabel,
            formattedStartTimeISO: formattedStartTimeISO
        )
    }

    // MARK: - Private Helpers

    /// Calculates the day label by comparing calendar days in the given timezone.
    ///
    /// - Parameters:
    ///   - triggerTime: The calculated trigger time
    ///   - referenceTime: The reference time
    ///   - timezone: The timezone for day boundary calculations
    /// - Returns: The appropriate day label
    private static func calculateDayLabel(
        triggerTime: Date,
        referenceTime: Date,
        timezone: TimeZone
    ) -> NIDayLabel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        let triggerDay = calendar.startOfDay(for: triggerTime)
        let referenceDay = calendar.startOfDay(for: referenceTime)

        // Calculate the difference in days
        let components = calendar.dateComponents([.day], from: referenceDay, to: triggerDay)
        let dayDifference = components.day ?? 0

        switch dayDifference {
        case 0:
            return .today
        case 1:
            return .tomorrow
        default:
            return .later
        }
    }

    /// Formats a date as ISO 8601 string with timezone offset.
    ///
    /// - Parameters:
    ///   - date: The date to format
    ///   - timezone: The timezone for the formatted output
    /// - Returns: ISO 8601 formatted string
    private static func formatISO8601(date: Date, timezone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withColonSeparatorInTimeZone
        ]
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}
