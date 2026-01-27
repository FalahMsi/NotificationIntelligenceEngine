// NotificationIntelligence.swift
// Notification Intelligence Engine - Swift
//
// Public module interface. Re-exports all public types.

/// Notification Intelligence Engine
///
/// A cross-platform library for deterministic event resolution and notification timing calculations.
///
/// ## Overview
///
/// NIE provides a single, well-defined function for determining the next upcoming event
/// from a collection of events, calculating when to trigger a notification, and
/// classifying the trigger time relative to the current day.
///
/// ## Basic Usage
///
/// ```swift
/// import NotificationIntelligence
///
/// let events = [
///     NIEvent(
///         id: "meeting-1",
///         startTime: meetingDate,
///         label: "Team Standup"
///     )
/// ]
///
/// let config = NIResolverConfig(
///     timezone: TimeZone(identifier: "America/New_York")!,
///     triggerLeadTimeMinutes: 15
/// )
///
/// if let result = NIResolver.resolveUpcomingEvent(
///     referenceTime: Date(),
///     events: events,
///     config: config
/// ) {
///     print("Next: \(result.event.label ?? result.event.id)")
///     print("Trigger at: \(result.triggerTime)")
///     print("Day: \(result.dayLabel)")
/// }
/// ```
///
/// ## Semantic Guarantees
///
/// 1. **Event Selection**: The next event is determined by `startTime > referenceTime`
/// 2. **Trigger Time**: Always `event.startTime - config.triggerLeadTimeMinutes`
/// 3. **Day Label**: Based on comparing trigger time's calendar day to reference time's day
/// 4. **Determinism**: Identical inputs produce identical outputs across all platforms

// All types are exported from their respective files:
// - NITypes.swift: NIEvent, NIResolverConfig, NIUpcomingEventInfo, NIDayLabel, AnyCodable
// - NIResolver.swift: NIResolver
