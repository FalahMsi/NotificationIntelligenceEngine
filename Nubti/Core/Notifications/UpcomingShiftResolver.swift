import Foundation
import os.log

// MARK: - UpcomingShiftResolver
/// Single source of truth for determining the upcoming shift from any point in time.
///
/// # Architectural Purpose
/// This component exists to permanently fix the "Pre-Day Reminder" bug where night shifts
/// were incorrectly labeled. It replaces ALL timeline-based date matching for notification semantics.
///
/// # SEMANTIC GUARANTEE (LOCKED - DO NOT MODIFY)
/// - Upcoming shift is identified ONLY by its START time
/// - Reminder timing is ALWAYS calculated from shift START
/// - Day label (today/tomorrow) is derived by comparing:
///   reminder delivery day vs shift START day
/// - Shift END time must NEVER be referenced in pre-day reminders
///
/// # Why This Exists
/// The previous bug occurred because `timeline.items.first(where: date == X)` was used
/// to find shifts. For overnight shifts (23:00→07:00), this approach fails because:
/// 1. Timeline items are indexed by their START date
/// 2. Searching for "tomorrow" misses today's night shift
/// 3. The hardcoded "tomorrow" wording was incorrect for same-day shifts
///
/// # Usage
/// ```swift
/// let resolver = UpcomingShiftResolver()
/// if let info = resolver.resolve(referenceTime: Date(), context: context) {
///     // info.dayLabel tells you "today" vs "tomorrow"
///     // info.startTime is the exact shift start
/// }
/// ```
///
/// - Important: ALL pre-day reminder logic MUST use this resolver.
///              Timeline-based date matching is FORBIDDEN for notification semantics.
struct UpcomingShiftResolver {

    // MARK: - Constants

    /// Maximum days to look ahead when searching for upcoming shift.
    /// Set to 7 to handle:
    /// - Multiple consecutive off days
    /// - Custom shift patterns
    /// - Extended rest cycles
    ///
    /// - Note: This value matches `scheduleLookAheadDays` in NotificationService for consistency.
    static let MAX_LOOKAHEAD_DAYS = 7

    // MARK: - Logging

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "UpcomingShiftResolver"
    )

    // MARK: - Day Label Type Alias

    /// Type alias for ShiftDayLabel to maintain backward compatibility
    /// and allow usage as `UpcomingShiftResolver.DayLabel` in existing code.
    ///
    /// The actual type is defined in ShiftDayLabel.swift to allow
    /// cross-file usage without circular dependencies.
    typealias DayLabel = ShiftDayLabel

    // MARK: - Upcoming Shift Info

    /// Complete information about the next upcoming shift.
    ///
    /// All fields are derived from ShiftEngine (the single source of truth for shift times).
    struct UpcomingShiftInfo {
        /// The shift phase (morning, evening, night)
        let phase: ShiftPhase

        /// Exact start datetime of the shift
        /// - Important: This is the ONLY time that matters for pre-day reminders
        let startTime: Date

        /// Exact end datetime of the shift
        /// - Warning: Do NOT use this for pre-day reminder content
        let endTime: Date

        /// Localized shift label ("صباحي" / "Morning")
        let shiftLabel: String

        /// Whether shift starts "today" or "tomorrow" relative to reference time
        /// - Important: This determines the wording in notification body
        let dayLabel: DayLabel

        /// Formatted start time string ("11:00 PM" or "٢٣:٠٠")
        let formattedStartTime: String

        /// The date the shift is scheduled for (start of day)
        let shiftDate: Date
    }

    // MARK: - Resolution

    /// Resolves the next upcoming shift from a given reference time.
    ///
    /// # Algorithm
    /// 1. Start from referenceTime's calendar day
    /// 2. Look ahead up to `MAX_LOOKAHEAD_DAYS` days
    /// 3. For each day, get the shift phase from ShiftEngine
    /// 4. Skip off days
    /// 5. Calculate exact start/end times using ShiftEngine
    /// 6. If shift START > referenceTime, this is the upcoming shift
    /// 7. Determine dayLabel by comparing calendar days
    ///
    /// # SEMANTIC GUARANTEE
    /// - Returns the shift that STARTS next (not the one that ENDS next)
    /// - Day label is based on when the shift STARTS, not when it ends
    ///
    /// - Parameters:
    ///   - referenceTime: The time from which to search (typically: now, or notification delivery time)
    ///   - context: The shift context containing user configuration
    ///   - manualOverrides: Optional manual shift overrides (takes precedence over calculated phase)
    /// - Returns: Information about the upcoming shift, or nil if none found in lookahead window
    func resolve(
        referenceTime: Date,
        context: ShiftContext,
        manualOverrides: [String: ShiftPhase] = [:]
    ) -> UpcomingShiftInfo? {

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = context.timeZone ?? .current

        let refDay = calendar.startOfDay(for: referenceTime)

        Self.logger.debug("Resolving upcoming shift [refTime=\(referenceTime), refDay=\(refDay)]")

        // Build timeline for lookahead window
        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: refDay,
            days: Self.MAX_LOOKAHEAD_DAYS
        )

        // Search through timeline items
        for item in timeline.items {
            let targetDay = calendar.startOfDay(for: item.date)
            let dayKeyStr = dayKey(for: targetDay, calendar: calendar)

            // Check for manual override
            let phase = manualOverrides[dayKeyStr] ?? item.phase

            // Skip off days
            guard phase.isCountedAsWorkDay else {
                Self.logger.debug("Skipping off day: \(targetDay)")
                continue
            }

            // Get exact times from ShiftEngine (SOURCE OF TRUTH)
            guard let times = ShiftEngine.shared.calculateExactShiftTimes(
                context: context,
                for: targetDay,
                phase: phase
            ) else {
                Self.logger.warning("Failed to calculate times for \(targetDay)")
                continue
            }

            // Check if this shift starts AFTER reference time
            // SEMANTIC RULE: We care about START time, not END time
            guard times.start > referenceTime else {
                Self.logger.debug("Shift already started: \(times.start) <= \(referenceTime)")
                continue
            }

            // Found the upcoming shift!
            // Determine day label by comparing calendar days
            // SEMANTIC RULE: Compare reminder delivery day vs shift START day
            let startDay = calendar.startOfDay(for: times.start)
            let dayLabel: DayLabel
            if startDay == refDay {
                dayLabel = .today
            } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: refDay),
                      startDay == calendar.startOfDay(for: tomorrow) {
                dayLabel = .tomorrow
            } else {
                // Shift is >1 day away (e.g., after multiple off days)
                dayLabel = .later
            }

            let info = UpcomingShiftInfo(
                phase: phase,
                startTime: times.start,
                endTime: times.end,
                shiftLabel: localizedShiftLabel(for: phase),
                dayLabel: dayLabel,
                formattedStartTime: formatTime(times.start),
                shiftDate: targetDay
            )

            Self.logger.info("Resolved upcoming shift [phase=\(phase.rawValue), start=\(times.start), dayLabel=\(dayLabel.rawValue)]")

            return info
        }

        // No upcoming shift found in lookahead window
        Self.logger.warning("No upcoming shift found in \(Self.MAX_LOOKAHEAD_DAYS)-day lookahead window")
        return nil
    }

    // MARK: - Helpers

    /// Generates a day key string for the given date.
    /// Uses DayKeyGenerator as single source of truth for consistent format.
    ///
    /// - Important: This MUST match the format used by UserShift.swift
    ///              to ensure manual overrides are correctly looked up.
    private func dayKey(for date: Date, calendar: Calendar) -> String {
        DayKeyGenerator.key(for: date, calendar: calendar)
    }

    /// Returns localized shift label for the given phase.
    private func localizedShiftLabel(for phase: ShiftPhase) -> String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"

        switch phase {
        case .morning:
            return isArabic ? "صباحي" : "morning"
        case .evening:
            return isArabic ? "مسائي" : "evening"
        case .night:
            return isArabic ? "ليلي" : "night"
        case .off, .firstOff, .secondOff:
            return isArabic ? "راحة" : "off"
        case .weekend:
            return isArabic ? "عطلة" : "weekend"
        case .leave:
            return isArabic ? "إجازة" : "leave"
        }
    }

    /// Formats a time for display in notifications.
    /// Uses 12-hour format with AM/PM for English, 24-hour for Arabic.
    private func formatTime(_ date: Date) -> String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"

        let formatter = DateFormatter()
        if isArabic {
            // Arabic: Use 24-hour format with Latin digits
            formatter.locale = Locale(identifier: "ar_SA@numbers=latn")
            formatter.dateFormat = "HH:mm"
        } else {
            // English: Use 12-hour format with AM/PM
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "h:mm a"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Architectural Notes

/*
 ⚠️ ARCHITECTURAL RULE (PERMANENT - DO NOT CIRCUMVENT):

 Timeline-based date matching MUST NOT be used for notification semantics.

 FORBIDDEN PATTERN:
 ```swift
 timeline.items.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrow) })
 ```

 REQUIRED PATTERN:
 ```swift
 UpcomingShiftResolver().resolve(referenceTime: now, context: context)
 ```

 WHY:
 - Timeline items are indexed by shift START date
 - Night shifts that START today but END tomorrow will be missed by "tomorrow" search
 - The resolver correctly finds the next shift by comparing START times

 ENFORCEMENT:
 - Code review must reject any new timeline-based date matching for reminders
 - This file serves as the canonical documentation of the correct approach

 SEMANTIC DEFINITIONS (LOCKED):
 - "Upcoming Shift": The next shift that STARTS after reference time
 - "Pre-Shift Reminder": Notification sent N hours before shift START
 - "Today/Tomorrow": Determined by comparing delivery day vs shift START day

 These definitions are non-negotiable and must not be changed without
 Principal Architect approval.
 */
