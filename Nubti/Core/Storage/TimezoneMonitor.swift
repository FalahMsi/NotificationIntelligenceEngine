import Foundation
import os.log

/// TimezoneMonitor
/// يراقب تغييرات المنطقة الزمنية عند عودة التطبيق من الخلفية.
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Usage
/// ```swift
/// // In scenePhase onChange:
/// if newPhase == .active {
///     if let change = TimezoneMonitor.shared.checkForTimezoneChange() {
///         // Handle timezone change
///     }
/// }
/// ```
final class TimezoneMonitor {

    // MARK: - Singleton
    static let shared = TimezoneMonitor()
    private init() {}

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "TimezoneMonitor"
    )

    // MARK: - Keys
    private let lastTimezoneKey = "last_known_timezone_identifier"
    private let lastTimezoneOffsetKey = "last_known_timezone_offset"

    // MARK: - Change Result

    /// نتيجة اكتشاف تغيير المنطقة الزمنية
    struct TimezoneChangeResult {
        /// المنطقة الزمنية السابقة
        let oldTimezone: TimeZone
        /// المنطقة الزمنية الجديدة
        let newTimezone: TimeZone
        /// فرق الساعات بين المنطقتين
        let hoursDifference: Int

        /// هل الفرق كبير بما يكفي لإبلاغ المستخدم؟
        var isSignificant: Bool {
            abs(hoursDifference) >= 1
        }

        var localizedDescription: String {
            let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
            if isArabic {
                return "تم اكتشاف تغيير في المنطقة الزمنية من \(oldTimezone.identifier) إلى \(newTimezone.identifier)"
            } else {
                return "Timezone changed from \(oldTimezone.identifier) to \(newTimezone.identifier)"
            }
        }
    }

    // MARK: - Core Logic

    /// التحقق مما إذا كانت المنطقة الزمنية قد تغيرت منذ آخر تحقق
    /// - Returns: معلومات التغيير إذا حدث تغيير، nil إذا لم يتغير شيء
    func checkForTimezoneChange() -> TimezoneChangeResult? {
        let defaults = UserDefaults.standard
        let currentTimezone = TimeZone.current

        // جلب المنطقة الزمنية المخزنة
        guard let storedIdentifier = defaults.string(forKey: lastTimezoneKey),
              let storedTimezone = TimeZone(identifier: storedIdentifier) else {
            // أول تشغيل - تخزين المنطقة الزمنية الحالية
            Self.logger.info("First run - storing current timezone: \(currentTimezone.identifier)")
            updateStoredTimezone(currentTimezone)
            return nil
        }

        // مقارنة المنطقتين
        if storedTimezone.identifier != currentTimezone.identifier {
            let hoursDiff = calculateHoursDifference(from: storedTimezone, to: currentTimezone)

            Self.logger.info("Timezone change detected: \(storedTimezone.identifier) → \(currentTimezone.identifier) (diff: \(hoursDiff)h)")

            let result = TimezoneChangeResult(
                oldTimezone: storedTimezone,
                newTimezone: currentTimezone,
                hoursDifference: hoursDiff
            )

            // تحديث المنطقة الزمنية المخزنة
            updateStoredTimezone(currentTimezone)

            return result
        }

        // لم يتغير شيء
        Self.logger.debug("Timezone unchanged: \(currentTimezone.identifier)")
        return nil
    }

    /// تحديث المنطقة الزمنية المخزنة
    func updateStoredTimezone(_ timezone: TimeZone = .current) {
        let defaults = UserDefaults.standard
        defaults.set(timezone.identifier, forKey: lastTimezoneKey)
        defaults.set(timezone.secondsFromGMT(), forKey: lastTimezoneOffsetKey)
        Self.logger.debug("Stored timezone updated: \(timezone.identifier)")
    }

    /// حساب فرق الساعات بين منطقتين زمنيتين
    private func calculateHoursDifference(from: TimeZone, to: TimeZone) -> Int {
        let fromOffset = from.secondsFromGMT()
        let toOffset = to.secondsFromGMT()
        let diffSeconds = toOffset - fromOffset
        return diffSeconds / 3600
    }

    /// الحصول على المنطقة الزمنية المخزنة (للتشخيص)
    func storedTimezone() -> TimeZone? {
        guard let identifier = UserDefaults.standard.string(forKey: lastTimezoneKey) else {
            return nil
        }
        return TimeZone(identifier: identifier)
    }

    /// مسح البيانات المخزنة (للاختبار أو إعادة التعيين)
    func clearStoredTimezone() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: lastTimezoneKey)
        defaults.removeObject(forKey: lastTimezoneOffsetKey)
        Self.logger.info("Stored timezone data cleared")
    }
}
