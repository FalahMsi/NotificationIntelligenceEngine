import Foundation
import os.log

// MARK: - Holiday Protocol

/// HolidayProvider
/// Protocol for providing official holidays for shift calculations.
///
/// # Design Principles
/// 1. Support multiple years dynamically
/// 2. Allow regional customization (Kuwait, UAE, Saudi, etc.)
/// 3. Cache holidays for performance
/// 4. Support both fixed and calculated holidays (Eid, etc.)
///
/// # Usage
/// ```swift
/// let provider = KuwaitHolidayProvider()
/// if provider.isHoliday(date) { ... }
/// ```
protocol HolidayProvider {
    /// The region identifier (e.g., "KW", "SA", "AE")
    var regionCode: String { get }

    /// Check if a specific date is a holiday
    /// - Parameter date: The date to check
    /// - Returns: true if the date is an official holiday
    func isHoliday(_ date: Date) -> Bool

    /// Get all holidays for a specific year
    /// - Parameter year: The year to get holidays for
    /// - Returns: Set of holiday dates (normalized to start of day)
    func holidays(forYear year: Int) -> Set<Date>

    /// Get holiday name if the date is a holiday
    /// - Parameter date: The date to check
    /// - Returns: Localized holiday name, or nil if not a holiday
    func holidayName(for date: Date) -> String?
}

// MARK: - Holiday Info

/// Information about a specific holiday
struct HolidayInfo: Codable, Hashable {
    let date: Date
    let nameArabic: String
    let nameEnglish: String
    let isNational: Bool

    var localizedName: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        return isArabic ? nameArabic : nameEnglish
    }
}

// MARK: - Kuwait Holiday Provider

/// KuwaitHolidayProvider
/// Official holidays for Kuwait with multi-year support.
///
/// # Fixed Holidays (Gregorian)
/// - February 25: National Day
/// - February 26: Liberation Day
///
/// # Estimated Islamic Holidays (Hijri → Gregorian)
/// - Isra and Mi'raj
/// - Eid al-Fitr (3 days)
/// - Eid al-Adha (4 days)
/// - Islamic New Year
/// - Prophet's Birthday
///
/// Note: Islamic holidays shift approximately 11 days earlier each Gregorian year.
/// These dates are ESTIMATES and should be updated annually from official government sources.
final class KuwaitHolidayProvider: HolidayProvider {

    // MARK: - Properties

    let regionCode = "KW"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "HolidayProvider"
    )

    // MARK: - Holiday Cache

    /// Cached holidays by year for performance
    private var holidayCache: [Int: Set<Date>] = [:]
    private var holidayInfoCache: [Date: HolidayInfo] = [:]

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kuwait") ?? .current
        return cal
    }()

    // MARK: - Protocol Conformance

    func isHoliday(_ date: Date) -> Bool {
        let year = calendar.component(.year, from: date)
        let holidays = holidays(forYear: year)
        let normalizedDate = calendar.startOfDay(for: date)
        return holidays.contains(normalizedDate)
    }

    func holidays(forYear year: Int) -> Set<Date> {
        // Check cache first
        if let cached = holidayCache[year] {
            return cached
        }

        // Build holidays for this year
        var holidays = Set<Date>()
        var infos: [Date: HolidayInfo] = [:]

        // Fixed holidays
        let fixedHolidays = buildFixedHolidays(year: year)
        for info in fixedHolidays {
            let normalizedDate = calendar.startOfDay(for: info.date)
            holidays.insert(normalizedDate)
            infos[normalizedDate] = info
        }

        // Islamic holidays (estimated)
        let islamicHolidays = buildIslamicHolidays(year: year)
        for info in islamicHolidays {
            let normalizedDate = calendar.startOfDay(for: info.date)
            holidays.insert(normalizedDate)
            infos[normalizedDate] = info
        }

        // Cache results
        holidayCache[year] = holidays
        holidayInfoCache.merge(infos) { _, new in new }

        Self.logger.info("Built \(holidays.count) holidays for year \(year)")

        return holidays
    }

    func holidayName(for date: Date) -> String? {
        let normalizedDate = calendar.startOfDay(for: date)
        return holidayInfoCache[normalizedDate]?.localizedName
    }

    // MARK: - Fixed Holidays

    private func buildFixedHolidays(year: Int) -> [HolidayInfo] {
        var holidays: [HolidayInfo] = []

        // National Day - February 25
        if let date = calendar.date(from: DateComponents(year: year, month: 2, day: 25)) {
            holidays.append(HolidayInfo(
                date: date,
                nameArabic: "اليوم الوطني",
                nameEnglish: "National Day",
                isNational: true
            ))
        }

        // Liberation Day - February 26
        if let date = calendar.date(from: DateComponents(year: year, month: 2, day: 26)) {
            holidays.append(HolidayInfo(
                date: date,
                nameArabic: "يوم التحرير",
                nameEnglish: "Liberation Day",
                isNational: true
            ))
        }

        // New Year's Day - January 1
        if let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
            holidays.append(HolidayInfo(
                date: date,
                nameArabic: "رأس السنة الميلادية",
                nameEnglish: "New Year's Day",
                isNational: false
            ))
        }

        return holidays
    }

    // MARK: - Islamic Holidays (Estimated)

    /// Build estimated Islamic holidays for a given Gregorian year.
    ///
    /// IMPORTANT: These dates are ESTIMATES based on astronomical calculations.
    /// Actual dates depend on moon sighting and may vary by 1-2 days.
    /// For production use, integrate with a reliable Islamic calendar API or
    /// update these dates annually from official government announcements.
    private func buildIslamicHolidays(year: Int) -> [HolidayInfo] {
        var holidays: [HolidayInfo] = []

        // Estimated dates for common years
        // These should be updated annually or calculated from Hijri calendar
        let estimatedDates = islamicHolidayEstimates(forYear: year)

        for estimate in estimatedDates {
            holidays.append(estimate)
        }

        return holidays
    }

    /// Returns estimated Islamic holiday dates for a given year.
    /// These are pre-calculated estimates - actual dates may vary.
    private func islamicHolidayEstimates(forYear year: Int) -> [HolidayInfo] {
        // Note: These dates shift ~11 days earlier each year
        // Values here are estimates and should be verified against official sources

        switch year {
        case 2024:
            return buildIslamicHolidaySet(year: 2024, eidFitr: (4, 10), eidAdha: (6, 16), islamicNewYear: (7, 7), prophetBirthday: (9, 15), israMiraj: (2, 7))

        case 2025:
            return buildIslamicHolidaySet(year: 2025, eidFitr: (3, 30), eidAdha: (6, 6), islamicNewYear: (6, 26), prophetBirthday: (9, 4), israMiraj: (1, 27))

        case 2026:
            return buildIslamicHolidaySet(year: 2026, eidFitr: (3, 20), eidAdha: (5, 27), islamicNewYear: (6, 16), prophetBirthday: (8, 25), israMiraj: (1, 17))

        case 2027:
            return buildIslamicHolidaySet(year: 2027, eidFitr: (3, 9), eidAdha: (5, 16), islamicNewYear: (6, 5), prophetBirthday: (8, 14), israMiraj: (1, 6))

        case 2028:
            return buildIslamicHolidaySet(year: 2028, eidFitr: (2, 26), eidAdha: (5, 4), islamicNewYear: (5, 25), prophetBirthday: (8, 3), israMiraj: (12, 26))

        case 2029:
            return buildIslamicHolidaySet(year: 2029, eidFitr: (2, 14), eidAdha: (4, 23), islamicNewYear: (5, 14), prophetBirthday: (7, 23), israMiraj: (12, 15))

        case 2030:
            return buildIslamicHolidaySet(year: 2030, eidFitr: (2, 3), eidAdha: (4, 12), islamicNewYear: (5, 3), prophetBirthday: (7, 12), israMiraj: (12, 5))

        default:
            // For unknown years, extrapolate from 2026 baseline
            // Islamic year is ~354 days, so shift ~11 days earlier per Gregorian year
            Self.logger.warning("No pre-calculated Islamic holidays for year \(year), using extrapolation")
            return extrapolateIslamicHolidays(forYear: year)
        }
    }

    /// Build a complete set of Islamic holidays for a year
    private func buildIslamicHolidaySet(
        year: Int,
        eidFitr: (month: Int, day: Int),
        eidAdha: (month: Int, day: Int),
        islamicNewYear: (month: Int, day: Int),
        prophetBirthday: (month: Int, day: Int),
        israMiraj: (month: Int, day: Int)
    ) -> [HolidayInfo] {
        var holidays: [HolidayInfo] = []

        // Eid al-Fitr (3 days)
        for offset in 0..<3 {
            if let baseDate = calendar.date(from: DateComponents(year: year, month: eidFitr.month, day: eidFitr.day)),
               let date = calendar.date(byAdding: .day, value: offset, to: baseDate) {
                holidays.append(HolidayInfo(
                    date: date,
                    nameArabic: "عيد الفطر",
                    nameEnglish: "Eid al-Fitr",
                    isNational: true
                ))
            }
        }

        // Eid al-Adha (4 days)
        for offset in 0..<4 {
            if let baseDate = calendar.date(from: DateComponents(year: year, month: eidAdha.month, day: eidAdha.day)),
               let date = calendar.date(byAdding: .day, value: offset, to: baseDate) {
                holidays.append(HolidayInfo(
                    date: date,
                    nameArabic: "عيد الأضحى",
                    nameEnglish: "Eid al-Adha",
                    isNational: true
                ))
            }
        }

        // Islamic New Year (1 day)
        if let date = calendar.date(from: DateComponents(year: year, month: islamicNewYear.month, day: islamicNewYear.day)) {
            holidays.append(HolidayInfo(
                date: date,
                nameArabic: "رأس السنة الهجرية",
                nameEnglish: "Islamic New Year",
                isNational: true
            ))
        }

        // Prophet's Birthday (1 day)
        if let date = calendar.date(from: DateComponents(year: year, month: prophetBirthday.month, day: prophetBirthday.day)) {
            holidays.append(HolidayInfo(
                date: date,
                nameArabic: "المولد النبوي",
                nameEnglish: "Prophet's Birthday",
                isNational: true
            ))
        }

        // Isra and Mi'raj (1 day)
        if let date = calendar.date(from: DateComponents(year: year, month: israMiraj.month, day: israMiraj.day)) {
            holidays.append(HolidayInfo(
                date: date,
                nameArabic: "الإسراء والمعراج",
                nameEnglish: "Isra and Mi'raj",
                isNational: true
            ))
        }

        return holidays
    }

    /// Extrapolate Islamic holidays for years without pre-calculated data
    private func extrapolateIslamicHolidays(forYear year: Int) -> [HolidayInfo] {
        // Use 2026 as baseline
        let baselineYear = 2026
        let yearDiff = year - baselineYear

        // Islamic year is ~354.37 days, so holidays shift ~10.88 days earlier per Gregorian year
        let dayShift = Int(Double(yearDiff) * 10.88)

        // 2026 baseline dates
        let baseline2026: [(month: Int, day: Int, nameAr: String, nameEn: String, days: Int)] = [
            (3, 20, "عيد الفطر", "Eid al-Fitr", 3),
            (5, 27, "عيد الأضحى", "Eid al-Adha", 4),
            (6, 16, "رأس السنة الهجرية", "Islamic New Year", 1),
            (8, 25, "المولد النبوي", "Prophet's Birthday", 1),
            (1, 17, "الإسراء والمعراج", "Isra and Mi'raj", 1)
        ]

        var holidays: [HolidayInfo] = []

        for baseline in baseline2026 {
            if let baseDate = calendar.date(from: DateComponents(year: baselineYear, month: baseline.month, day: baseline.day)),
               let shiftedDate = calendar.date(byAdding: .day, value: -dayShift, to: baseDate) {

                // Adjust year to target year
                var components = calendar.dateComponents([.month, .day], from: shiftedDate)
                components.year = year

                // Handle year wrap-around
                if let adjustedDate = calendar.date(from: components) {
                    for offset in 0..<baseline.days {
                        if let date = calendar.date(byAdding: .day, value: offset, to: adjustedDate) {
                            holidays.append(HolidayInfo(
                                date: date,
                                nameArabic: baseline.nameAr,
                                nameEnglish: baseline.nameEn,
                                isNational: true
                            ))
                        }
                    }
                }
            }
        }

        return holidays
    }
}

// MARK: - Holiday Provider Registry

/// HolidayProviderRegistry
/// Manages available holiday providers for different regions.
final class HolidayProviderRegistry {

    static let shared = HolidayProviderRegistry()

    private var providers: [String: HolidayProvider] = [:]
    private var activeProvider: HolidayProvider

    private init() {
        // Default to Kuwait
        let kuwaitProvider = KuwaitHolidayProvider()
        providers["KW"] = kuwaitProvider
        activeProvider = kuwaitProvider
    }

    /// Register a holiday provider for a region
    func register(_ provider: HolidayProvider) {
        providers[provider.regionCode] = provider
    }

    /// Set the active region
    func setActiveRegion(_ regionCode: String) {
        if let provider = providers[regionCode] {
            activeProvider = provider
        }
    }

    /// Get the current active provider
    var current: HolidayProvider {
        activeProvider
    }

    /// Check if a date is a holiday in the active region
    func isHoliday(_ date: Date) -> Bool {
        activeProvider.isHoliday(date)
    }

    /// Get holiday name for a date
    func holidayName(for date: Date) -> String? {
        activeProvider.holidayName(for: date)
    }
}
