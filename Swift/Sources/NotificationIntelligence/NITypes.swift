// NITypes.swift
// Notification Intelligence Engine - Swift
//
// Core type definitions for the Notification Intelligence Engine.
// These types form the public API contract.

import Foundation

// MARK: - DayLabel

/// Represents the relative day classification of a trigger time compared to a reference time.
///
/// The day label is determined by comparing calendar days in the configured timezone:
/// - `today`: Trigger time falls on the same calendar day as reference time
/// - `tomorrow`: Trigger time falls on the next calendar day
/// - `later`: Trigger time falls on any day beyond tomorrow
///
/// **Important**: The day label is based on the **trigger time**, not the event start time.
public enum NIDayLabel: String, Codable, Equatable, Sendable {
    case today
    case tomorrow
    case later
}

// MARK: - Event

/// Represents a schedulable event with a start time and optional metadata.
///
/// Events are the primary input to the resolver. The `startTime` is the only
/// field used for chronological ordering and selection.
public struct NIEvent: Equatable {
    /// Unique identifier for this event.
    public let id: String

    /// When the event begins. This is the primary field used for selection.
    public let startTime: Date

    /// When the event ends (optional).
    public let endTime: Date?

    /// Human-readable label for the event (optional).
    public let label: String?

    /// Arbitrary metadata associated with the event (optional).
    public let metadata: [String: AnyCodable]?

    /// Creates a new event.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this event
    ///   - startTime: When the event begins
    ///   - endTime: When the event ends (optional)
    ///   - label: Human-readable label (optional)
    ///   - metadata: Arbitrary key-value data (optional)
    public init(
        id: String,
        startTime: Date,
        endTime: Date? = nil,
        label: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.label = label
        self.metadata = metadata
    }
}

// MARK: - ResolverConfig

/// Configuration for the upcoming event resolver.
///
/// The resolver uses this configuration to determine:
/// - Which timezone to use for day boundary calculations
/// - How far ahead to look for events
/// - How much lead time to apply for trigger calculations
/// - Which events to skip
public struct NIResolverConfig {
    /// The timezone used for day boundary calculations (required).
    ///
    /// This timezone determines what constitutes "today", "tomorrow", and "later"
    /// when calculating day labels.
    public let timezone: TimeZone

    /// Number of days to look ahead for events. Default is 7.
    ///
    /// Events with `startTime` beyond `referenceTime + lookaheadDays` are not considered.
    public let lookaheadDays: Int

    /// Minutes before the event start time to calculate the trigger time. Default is 0.
    ///
    /// Formula: `triggerTime = event.startTime - triggerLeadTimeMinutes`
    public let triggerLeadTimeMinutes: Int

    /// BCP-47 locale identifier (optional).
    ///
    /// **Note**: This is NOT used for core semantic calculations. It may be used
    /// by consuming code for formatting purposes.
    public let locale: Locale?

    /// Predicate to determine if an event should be skipped (optional).
    ///
    /// If this returns `true` for an event, that event will not be considered
    /// for selection, even if it would otherwise be the next upcoming event.
    public let skipPredicate: ((NIEvent) -> Bool)?

    /// Creates a new resolver configuration.
    ///
    /// - Parameters:
    ///   - timezone: The timezone for day boundary calculations
    ///   - lookaheadDays: Days to look ahead (default: 7)
    ///   - triggerLeadTimeMinutes: Minutes before event to trigger (default: 0)
    ///   - locale: BCP-47 locale identifier (optional)
    ///   - skipPredicate: Filter function for events (optional)
    public init(
        timezone: TimeZone,
        lookaheadDays: Int = 7,
        triggerLeadTimeMinutes: Int = 0,
        locale: Locale? = nil,
        skipPredicate: ((NIEvent) -> Bool)? = nil
    ) {
        self.timezone = timezone
        self.lookaheadDays = lookaheadDays
        self.triggerLeadTimeMinutes = triggerLeadTimeMinutes
        self.locale = locale
        self.skipPredicate = skipPredicate
    }
}

// MARK: - UpcomingEventInfo

/// The result of resolving the next upcoming event.
///
/// Contains the selected event along with calculated timing information.
public struct NIUpcomingEventInfo: Equatable {
    /// The selected upcoming event.
    public let event: NIEvent

    /// The event's start time.
    public let startTime: Date

    /// The event's end time (if present).
    public let endTime: Date?

    /// When the notification should be triggered.
    ///
    /// Calculated as: `event.startTime - config.triggerLeadTimeMinutes`
    public let triggerTime: Date

    /// The relative day classification of the trigger time.
    ///
    /// Based on comparing `triggerTime` to `referenceTime` in the configured timezone.
    public let dayLabel: NIDayLabel

    /// ISO 8601 formatted representation of the start time.
    ///
    /// This provides a deterministic string representation across platforms.
    public let formattedStartTimeISO: String

    /// Creates a new upcoming event info.
    ///
    /// - Parameters:
    ///   - event: The selected event
    ///   - startTime: Event start time
    ///   - endTime: Event end time (optional)
    ///   - triggerTime: Calculated trigger time
    ///   - dayLabel: Relative day classification
    ///   - formattedStartTimeISO: ISO 8601 formatted start time
    public init(
        event: NIEvent,
        startTime: Date,
        endTime: Date?,
        triggerTime: Date,
        dayLabel: NIDayLabel,
        formattedStartTimeISO: String
    ) {
        self.event = event
        self.startTime = startTime
        self.endTime = endTime
        self.triggerTime = triggerTime
        self.dayLabel = dayLabel
        self.formattedStartTimeISO = formattedStartTimeISO
    }
}

// MARK: - AnyCodable

/// A type-erased Codable value for storing arbitrary metadata.
public struct AnyCodable: Codable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode AnyCodable"
                )
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        default:
            return false
        }
    }
}
