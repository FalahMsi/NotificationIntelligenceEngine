import Foundation

/// DayKeyGenerator
/// Single source of truth for generating day keys used in manual overrides.
///
/// # Format
/// All day keys use zero-padded format: `YYYY-MM-DD`
/// Example: `2026-01-27` (not `2026-1-27`)
///
/// # Why This Exists
/// Previously, UserShift.swift used non-padded format (`2026-1-27`)
/// while UpcomingShiftResolver.swift used padded format (`2026-01-27`).
/// This mismatch caused manual overrides to be silently ignored.
///
/// # Usage
/// ```swift
/// let key = DayKeyGenerator.key(for: date)
/// let key = DayKeyGenerator.key(for: date, calendar: myCalendar)
/// ```
///
/// # ARCHITECTURAL RULE
/// ALL code that generates or looks up day keys MUST use this generator.
/// Do NOT create inline day key formatting.
enum DayKeyGenerator {

    // MARK: - Canonical Format

    /// Generates a zero-padded day key for the given date.
    /// Format: `YYYY-MM-DD` (e.g., `2026-01-27`)
    ///
    /// - Parameters:
    ///   - date: The date to generate a key for
    ///   - calendar: Calendar to use for date components (defaults to gregorian with current timezone)
    /// - Returns: Zero-padded day key string
    static func key(for date: Date, calendar: Calendar? = nil) -> String {
        let cal = calendar ?? defaultCalendar
        let components = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    // MARK: - Legacy Support

    /// Generates a legacy (non-padded) day key for backward compatibility.
    /// Format: `YYYY-M-D` (e.g., `2026-1-27`)
    ///
    /// - Warning: Only use this for reading legacy stored data.
    ///           New code should ALWAYS use `key(for:calendar:)`.
    static func legacyKey(for date: Date, calendar: Calendar? = nil) -> String {
        let cal = calendar ?? defaultCalendar
        let components = cal.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    /// Checks if a key is in legacy (non-zero-padded) format.
    ///
    /// - Parameter key: The day key to check
    /// - Returns: True if the key contains non-zero-padded components
    static func isLegacyFormat(_ key: String) -> Bool {
        let parts = key.split(separator: "-")
        guard parts.count == 3 else { return false }
        // Legacy format has single-digit month or day without leading zero
        // e.g., "2026-1-5" instead of "2026-01-05"
        return parts[1].count == 1 || parts[2].count == 1
    }

    /// Converts a legacy key to canonical format if needed.
    /// If already in canonical format, returns as-is.
    ///
    /// - Parameter key: The day key (may be legacy or canonical)
    /// - Returns: Canonical zero-padded key
    static func canonicalize(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return key // Can't parse, return as-is
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Private

    private static var defaultCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }
}
