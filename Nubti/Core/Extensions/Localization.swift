import Foundation
import SwiftUI

// MARK: - Legacy Translation Helper

/// Legacy bilingual translation helper.
/// Returns Arabic or English text based on the current app language setting.
///
/// Usage: `tr("نص عربي", "English text")`
///
/// - Note: This function is maintained for backward compatibility.
///         New code should use `L10n.key` or `String.localized("key")` instead.
///
/// - Warning: This function bypasses proper localization infrastructure.
///            Migrate to Localizable.strings over time.
func tr(_ ar: String, _ en: String) -> String {
    let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
    return isArabic ? ar : en
}

// MARK: - Proper Localization

/// String extension for proper localization support.
/// Uses NSLocalizedString with the correct bundle based on user's language preference.
extension String {

    /// Returns the localized version of this string key.
    ///
    /// Usage:
    /// ```swift
    /// let text = "common.today".localized  // Returns "Today" or "اليوم"
    /// let text = String.localized("common.today")
    /// ```
    ///
    /// - Returns: The localized string, or the key itself if not found
    var localized: String {
        String.localized(self)
    }

    /// Returns the localized string for the given key.
    ///
    /// - Parameter key: The localization key (e.g., "common.today")
    /// - Returns: The localized string
    static func localized(_ key: String) -> String {
        let languageCode = UserDefaults.standard.string(forKey: "app_language") ?? "ar"
        let bundle = Bundle.localizedBundle(for: languageCode)
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// Returns the localized string with format arguments.
    ///
    /// Usage:
    /// ```swift
    /// let text = String.localized("notification.preDay.bodyToday", "morning", "7:00 AM")
    /// // Returns "You have a morning shift today starting at 7:00 AM."
    /// ```
    ///
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Format arguments to substitute
    /// - Returns: The formatted localized string
    static func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Bundle Extension

extension Bundle {

    /// Returns the appropriate bundle for the specified language code.
    ///
    /// This allows switching language at runtime without restarting the app.
    ///
    /// - Parameter languageCode: The language code ("ar" or "en")
    /// - Returns: The bundle containing localizations for that language
    static func localizedBundle(for languageCode: String) -> Bundle {
        // Map language code to lproj folder
        let lprojName: String
        switch languageCode {
        case "ar":
            lprojName = "ar"
        case "en":
            lprojName = "en"
        default:
            lprojName = "ar" // Default to Arabic for Kuwait
        }

        // Find the bundle path
        if let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        // Fallback to main bundle
        return Bundle.main
    }
}

// MARK: - L10n Namespace (Type-Safe Keys)

/// Type-safe localization keys.
///
/// Usage:
/// ```swift
/// Text(L10n.common.today)
/// Text(L10n.phase.morning)
/// ```
///
/// This provides autocomplete and compile-time checking for localization keys.
enum L10n {

    // MARK: - Common

    enum common {
        static var today: String { "common.today".localized }
        static var tomorrow: String { "common.tomorrow".localized }
        static var later: String { "common.later".localized }
        static var cancel: String { "common.cancel".localized }
        static var confirm: String { "common.confirm".localized }
        static var save: String { "common.save".localized }
        static var delete: String { "common.delete".localized }
        static var edit: String { "common.edit".localized }
        static var done: String { "common.done".localized }
        static var close: String { "common.close".localized }
        static var yes: String { "common.yes".localized }
        static var no: String { "common.no".localized }
        static var ok: String { "common.ok".localized }
        static var error: String { "common.error".localized }
        static var success: String { "common.success".localized }
        static var loading: String { "common.loading".localized }
        static var retry: String { "common.retry".localized }
        static var noData: String { "common.noData".localized }
    }

    // MARK: - Shift Phases

    enum phase {
        static var morning: String { "phase.morning".localized }
        static var evening: String { "phase.evening".localized }
        static var night: String { "phase.night".localized }
        static var off: String { "phase.off".localized }
        static var firstOff: String { "phase.firstOff".localized }
        static var secondOff: String { "phase.secondOff".localized }
        static var weekend: String { "phase.weekend".localized }
        static var leave: String { "phase.leave".localized }
    }

    // MARK: - Phase Labels (Short)

    enum phaseLabel {
        static var morning: String { "phaseLabel.morning".localized }
        static var evening: String { "phaseLabel.evening".localized }
        static var night: String { "phaseLabel.night".localized }
        static var off: String { "phaseLabel.off".localized }
        static var weekend: String { "phaseLabel.weekend".localized }
        static var leave: String { "phaseLabel.leave".localized }
    }

    // MARK: - Calendar

    enum calendar {
        static var title: String { "calendar.title".localized }
        static var today: String { "calendar.today".localized }
        static var selectYear: String { "calendar.selectYear".localized }
    }

    // MARK: - Hero Card

    enum hero {
        static var shiftCompleted: String { "hero.shiftCompleted".localized }
        static var startsIn: String { "hero.startsIn".localized }
        static var remaining: String { "hero.remaining".localized }
        static var dayOff: String { "hero.dayOff".localized }
        static var onLeave: String { "hero.onLeave".localized }
        static var noData: String { "hero.noData".localized }
        static var hours: String { "hero.hours".localized }
        static var minutes: String { "hero.minutes".localized }
    }

    // MARK: - Notifications

    enum notification {
        enum preDay {
            static func bodyToday(shiftLabel: String, startTime: String) -> String {
                String.localized("notification.preDay.bodyToday", shiftLabel, startTime)
            }
            static func bodyTomorrow(shiftLabel: String, startTime: String) -> String {
                String.localized("notification.preDay.bodyTomorrow", shiftLabel, startTime)
            }
        }
    }

    // MARK: - Wizard

    enum wizard {
        static var title: String { "wizard.title".localized }
        static var message: String { "wizard.message".localized }
        static var confirm: String { "wizard.confirm".localized }
        static var later: String { "wizard.later".localized }
    }

    // MARK: - Errors

    enum error {
        static var generic: String { "error.generic".localized }
        static var noPermission: String { "error.noPermission".localized }
        static var networkError: String { "error.networkError".localized }
        static var dataCorruption: String { "error.dataCorruption".localized }
    }
}
