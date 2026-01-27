import Foundation

// MARK: - ShiftDayLabel
/// Represents whether a shift starts "today" or "tomorrow" relative to reminder delivery.
///
/// # SEMANTIC RULE (LOCKED - DO NOT MODIFY)
/// This is determined by comparing:
/// - Calendar day of reminder DELIVERY time
/// - Calendar day of shift START time
///
/// If both are the same calendar day → `.today`
/// Otherwise → `.tomorrow`
///
/// # Architectural Note
/// This enum is defined at the top level (not nested) to allow usage across
/// multiple files without circular dependency issues.
///
/// # Usage
/// - `UpcomingShiftResolver` produces this value
/// - `MessageData` consumes this value
/// - `MessageTemplate` uses this to select correct wording
///
/// # IMPORTANT
/// Never hardcode "today"/"tomorrow" strings in notification code.
/// Always use this enum and its `localized` property.
enum ShiftDayLabel: String, Sendable {
    case today      // اليوم
    case tomorrow   // غداً
    case later      // لاحقاً (>1 day ahead, e.g., after multiple off days)

    /// Localized string for use in notifications
    var localized: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        switch self {
        case .today:
            return isArabic ? "اليوم" : "today"
        case .tomorrow:
            return isArabic ? "غداً" : "tomorrow"
        case .later:
            // For shifts >1 day away, use a more general phrasing
            // The actual date should be included in the notification body
            return isArabic ? "قريباً" : "soon"
        }
    }
}
