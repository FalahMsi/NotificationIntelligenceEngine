import Foundation

// MARK: - Phase 2: Safe Number Formatting Utilities
// These utilities ensure consistent Latin digit display (0-9)
// and prevent year grouping separators ("2,026" → "2026")

/// Safe year formatting - never uses grouping separators
/// Always returns Latin digits regardless of locale
///
/// Usage: `formatYear(2026)` → "2026" (never "2,026" or "٢٠٢٦")
func formatYear(_ year: Int) -> String {
    return String(year)  // Direct conversion bypasses locale formatting
}

// MARK: - NumberFormatter Extension

extension NumberFormatter {
    /// Pre-configured formatter that always uses Latin digits without grouping
    static let latinDigits: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.usesGroupingSeparator = false
        return f
    }()
}

// MARK: - Locale Extension for Latin Digits

extension Locale {
    /// Arabic locale variant that forces Latin digits (0-9 instead of ٠-٩)
    /// Uses the @numbers=latn Unicode extension
    static let latinDigitsArabic = Locale(identifier: "ar_SA@numbers=latn")

    /// English POSIX locale - always uses Latin digits
    static let latinDigitsEnglish = Locale(identifier: "en_US_POSIX")

    /// Returns a locale for the given language that always uses Latin digits
    /// - Parameter language: The app language setting
    /// - Returns: A locale configured to display Latin digits (0-9)
    ///
    /// Usage:
    /// ```swift
    /// let formatter = DateFormatter()
    /// formatter.locale = .latinDigits(for: settings.language)
    /// ```
    static func latinDigits(for language: AppLanguage) -> Locale {
        switch language {
        case .arabic: return .latinDigitsArabic
        case .english: return .latinDigitsEnglish
        }
    }
}
