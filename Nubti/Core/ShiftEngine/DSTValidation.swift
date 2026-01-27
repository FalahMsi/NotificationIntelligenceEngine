import Foundation
import os.log

/// DSTValidation
/// طبقة التحقق من التوقيت الصيفي وتعديل أوقات النوبات.
/// يُستخدم فقط في المناطق التي تطبق التوقيت الصيفي (مصر، أوروبا، أمريكا).
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## When to Use
/// - Spring Forward: الساعة تقفز من 2:00 إلى 3:00
/// - Fall Back: الساعة ترجع من 3:00 إلى 2:00
///
/// ## Kuwait Context
/// الكويت لا تستخدم التوقيت الصيفي، لذا هذا المكون معطل افتراضياً
/// ويمكن تفعيله عبر FeatureFlags.DST_AWARE_MODE للمناطق الأخرى
struct DSTValidation {

    // MARK: - Singleton
    static let shared = DSTValidation()
    private init() {}

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "DSTValidation"
    )

    // MARK: - Validation Result

    /// نتيجة التحقق من DST
    struct ValidationResult {
        /// هل التاريخ في نافذة انتقال DST؟
        let isInDSTWindow: Bool
        /// نوع الانتقال (إن وجد)
        let transition: DSTTransition?
        /// الوقت المعدّل (إن لزم التعديل)
        let adjustedTime: Date?
        /// رسالة للمستخدم
        let userMessage: String?

        /// نتيجة سليمة (لا يوجد DST)
        static let clean = ValidationResult(
            isInDSTWindow: false,
            transition: nil,
            adjustedTime: nil,
            userMessage: nil
        )
    }

    /// نوع انتقال DST
    enum DSTTransition {
        case springForward  // الساعة تتقدم (ساعة مفقودة)
        case fallBack       // الساعة ترجع (ساعة مكررة)

        var localizedName: String {
            let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
            switch self {
            case .springForward:
                return isArabic ? "التوقيت الصيفي (تقديم)" : "Spring Forward"
            case .fallBack:
                return isArabic ? "التوقيت الشتوي (تأخير)" : "Fall Back"
            }
        }
    }

    // MARK: - Core Validation

    /// التحقق من أن الوقت في نافذة انتقال DST
    /// - Parameters:
    ///   - date: التاريخ والوقت للتحقق
    ///   - timezone: المنطقة الزمنية
    /// - Returns: نتيجة التحقق
    func validateShiftTime(date: Date, timezone: TimeZone = .current) -> ValidationResult {
        // تحقق من الـ Feature Flag أولاً
        guard FeatureFlags.DST_AWARE_MODE else {
            return .clean
        }

        // التحقق مما إذا كان اليوم يوم انتقال DST
        guard let transition = detectDSTTransition(on: date, in: timezone) else {
            return .clean
        }

        Self.logger.info("DST transition detected on \(date): \(transition.localizedName)")

        // حساب الوقت المعدّل
        let adjustedTime = adjustForDST(date: date, transition: transition)

        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        let message = isArabic
            ? "تنبيه: اليوم يوم تغيير الساعة (\(transition.localizedName))"
            : "Note: Clock change today (\(transition.localizedName))"

        return ValidationResult(
            isInDSTWindow: true,
            transition: transition,
            adjustedTime: adjustedTime,
            userMessage: FeatureFlags.DST_SHOW_ALERTS ? message : nil
        )
    }

    // MARK: - DST Detection

    /// اكتشاف انتقال DST في يوم معين
    private func detectDSTTransition(on date: Date, in timezone: TimeZone) -> DSTTransition? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        // الحصول على بداية اليوم ونهايته
        guard let startOfDay = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date)),
              let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        // مقارنة offset في بداية ونهاية اليوم
        let startOffset = timezone.secondsFromGMT(for: startOfDay)
        let endOffset = timezone.secondsFromGMT(for: endOfDay)

        if endOffset > startOffset {
            // الساعة تقدمت = Spring Forward
            return .springForward
        } else if endOffset < startOffset {
            // الساعة رجعت = Fall Back
            return .fallBack
        }

        return nil
    }

    // MARK: - Time Adjustment

    /// تعديل الوقت للتعامل مع انتقال DST
    private func adjustForDST(date: Date, transition: DSTTransition) -> Date {
        switch transition {
        case .springForward:
            // الساعة من 2:00 إلى 3:00 "مفقودة"
            // إذا كان الوقت في هذه النافذة، نقفز للساعة الصالحة التالية
            return adjustForSpringForward(date: date)

        case .fallBack:
            // الساعة من 2:00 إلى 3:00 "مكررة"
            // نستخدم الحدث الأول (قبل التراجع)
            return adjustForFallBack(date: date)
        }
    }

    /// تعديل للـ Spring Forward (الساعة المفقودة)
    private func adjustForSpringForward(date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // إذا كان الوقت بين 2:00 و 3:00، نقفز إلى 3:00
        if hour == 2 {
            if let adjusted = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: date) {
                Self.logger.debug("Spring forward adjustment: \(date) → \(adjusted)")
                return adjusted
            }
        }

        return date
    }

    /// تعديل للـ Fall Back (الساعة المكررة)
    private func adjustForFallBack(date: Date) -> Date {
        // نستخدم الوقت كما هو (الحدث الأول)
        // في التطبيقات الأكثر تعقيداً، قد نحتاج لتتبع أي "نسخة" من الساعة
        Self.logger.debug("Fall back: using first occurrence")
        return date
    }

    // MARK: - Helpers

    /// التحقق مما إذا كانت المنطقة الزمنية تستخدم DST
    func timeZoneUsesDST(_ timezone: TimeZone = .current) -> Bool {
        // نتحقق من وجود انتقال DST في السنة الحالية
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)

        // نفحص كل شهر للتحقق من وجود تغيير في offset
        for month in 1...12 {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            let startOffset = timezone.secondsFromGMT(for: monthStart)
            let endOffset = timezone.secondsFromGMT(for: monthEnd)

            if startOffset != endOffset {
                return true
            }
        }

        return false
    }
}
