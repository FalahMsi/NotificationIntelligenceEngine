import Foundation

/// SystemMessage
/// يمثل رسالة / تحديث داخلي موحّد وآمن.
/// يعتمد على `kind` لتحديد المحتوى بدلاً من النصوص المباشرة لدعم الترجمة الفورية.
struct SystemMessage: Identifiable, Codable, Equatable {

    // MARK: - Identity
    let id: UUID

    // MARK: - Source
    let sourceType: SystemMessageSource
    let sourceID: UUID?

    // MARK: - Kind (🔥 جديد – يمنع النصوص العشوائية)
    let kind: SystemMessageKind

    // MARK: - Metadata
    let date: Date
    var isRead: Bool

    // MARK: - Computed Content (Localized)
    // يتم حساب النصوص وقت الطلب لضمان ظهورها بلغة المستخدم الحالية دائماً

    var title: String {
        kind.localizedTitle
    }

    var body: String {
        kind.localizedBody(date: date)
    }

    // MARK: - Init (المسار الصحيح)

    init(
        id: UUID = UUID(),
        sourceType: SystemMessageSource,
        sourceID: UUID? = nil,
        kind: SystemMessageKind,
        date: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.kind = kind
        self.date = date
        self.isRead = isRead
    }

    // MARK: - Legacy Init (🛡️ حماية من الكود القديم)
    // هذا المُنشئ يضمن أن أي كود قديم يرسل نصوصاً مباشرة لن يتسبب في انهيار التطبيق
    init(
        id: UUID = UUID(),
        sourceType: SystemMessageSource,
        sourceID: UUID? = nil,
        title: String,
        body: String,
        date: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.kind = .legacy(title: title, body: body)
        self.date = date
        self.isRead = isRead
    }
}

// MARK: - Message Kind

enum SystemMessageKind: Codable, Equatable {

    case leaveRegistered
    case shiftUpdated
    case attendanceMarked
    case achievementReminder
    case systemNotice(textAr: String, textEn: String)

    /// ✅ P1: Hourly permission added (stores raw type for localization at display time)
    case hourlyPermissionAdded(eventType: String, durationMinutes: Int, eventDate: Date)

    /// ✅ P1: Manual override set (stores raw phase for localization at display time)
    case manualOverrideSet(toPhase: String, overrideDate: Date)

    /// ✅ P1: Manual override cleared
    case manualOverrideCleared(overrideDate: Date)

    /// دعم الرسائل القديمة أو المخصصة جداً
    case legacy(title: String, body: String)

    // MARK: - Phase 3: Notification Events (Trust Observability)

    /// ✅ P3: Notifications scheduled (batch)
    /// - scheduledCount: Number of notifications scheduled
    /// - dateRange: Human-readable date range (e.g., "Jan 26 - Feb 1")
    case notificationsScheduled(scheduledCount: Int, dateRange: String)

    /// ✅ P3: Notification verified in foreground (via willPresent)
    case notificationVerifiedForeground

    /// ✅ P3: Notification verified via user interaction (via didReceive)
    case notificationVerifiedInteraction

    /// ✅ P3: Notification scheduling failed
    /// - failedCount: Number of notifications that failed
    /// - reason: User-friendly reason
    case notificationsFailed(failedCount: Int, reason: String)

    // MARK: - Phase 4: Reference Date Validation (Government-Grade Hardening)

    /// ✅ P4: Reference date corruption detected
    /// - reason: The validation failure reason
    case referenceDateCorruptionDetected(reason: String)

    /// ✅ P4: Reference date recovered successfully
    /// - method: How recovery was performed (e.g., "wizard", "backup")
    case referenceDateRecovered(method: String)

    /// ✅ P4: Reference date reset required (could not recover)
    case referenceDateResetRequired

    /// ✅ P4: Timezone changed
    /// - oldTimezone: Previous timezone identifier
    /// - newTimezone: New timezone identifier
    case timezoneChanged(oldTimezone: String, newTimezone: String)

    /// ✅ P5: System diagnostic message (used when invalid code path is reached)
    /// This replaces fatalError() to maintain app stability while logging errors.
    case systemDiagnostic

    // MARK: - Localization Logic

    var localizedTitle: String {
        let isArabic = SystemMessageLanguage.isArabic

        switch self {
        case .leaveRegistered:
            return isArabic ? "تم تسجيل إجازة" : "Leave Registered"

        case .shiftUpdated:
            return isArabic ? "تحديث نوبة" : "Shift Updated"

        case .attendanceMarked:
            return isArabic ? "تم تسجيل الحضور" : "Attendance Marked"

        case .achievementReminder:
            return isArabic ? "سجل إنجازك" : "Log Achievement"

        case .systemNotice(let ar, let en):
            return isArabic ? ar : en

        case .hourlyPermissionAdded:
            return isArabic ? "تم تسجيل استئذان" : "Permission Logged"

        case .manualOverrideSet:
            return isArabic ? "تعديل يدوي" : "Manual Override"

        case .manualOverrideCleared:
            return isArabic ? "إلغاء تعديل" : "Override Cleared"

        case .legacy(let title, _):
            return title

        // Phase 3: Notification Events
        case .notificationsScheduled:
            return isArabic ? "تم جدولة التنبيهات" : "Notifications Scheduled"

        case .notificationVerifiedForeground:
            return isArabic ? "تم التحقق من التنبيه" : "Notification Verified"

        case .notificationVerifiedInteraction:
            return isArabic ? "تم التحقق من التنبيه" : "Notification Verified"

        case .notificationsFailed:
            return isArabic ? "فشل جدولة بعض التنبيهات" : "Some Notifications Failed"

        // Phase 4: Reference Date Validation
        case .referenceDateCorruptionDetected:
            return isArabic ? "تم اكتشاف خلل في البيانات" : "Data Issue Detected"

        case .referenceDateRecovered:
            return isArabic ? "تم استعادة البيانات" : "Data Recovered"

        case .referenceDateResetRequired:
            return isArabic ? "يلزم إعادة الإعداد" : "Setup Required"

        case .timezoneChanged:
            return isArabic ? "تغيير المنطقة الزمنية" : "Timezone Changed"

        case .systemDiagnostic:
            return isArabic ? "تشخيص النظام" : "System Diagnostic"
        }
    }

    func localizedBody(date: Date) -> String {
        let isArabic = SystemMessageLanguage.isArabic
        let formatter = SystemMessageLanguage.dateFormatter
        let dateText = formatter.string(from: date)

        switch self {
        case .leaveRegistered:
            return isArabic
            ? "تم تسجيل الإجازة بنجاح بتاريخ \(dateText)."
            : "Leave successfully registered on \(dateText)."

        case .shiftUpdated:
            return isArabic
            ? "تم تحديث تفاصيل النوبة الخاصة بك."
            : "Your shift details have been updated."

        case .attendanceMarked:
            return isArabic
            ? "تم توثيق حضورك في السجل."
            : "Your attendance has been recorded."

        case .achievementReminder:
            return isArabic
            ? "لا تنسَ توثيق إنجازاتك لليوم في السجل."
            : "Don't forget to log today's achievements."

        case .systemNotice(let ar, let en):
            return isArabic ? ar : en

        case .hourlyPermissionAdded(let eventType, let durationMinutes, let eventDate):
            let eventDateText = formatter.string(from: eventDate)
            let localizedType = Self.localizeEventType(eventType, isArabic: isArabic)
            let durationText = durationMinutes >= 60
                ? (isArabic ? "\(durationMinutes / 60) ساعة" : "\(durationMinutes / 60)h")
                : (isArabic ? "\(durationMinutes) دقيقة" : "\(durationMinutes) min")
            return isArabic
                ? "تم تسجيل \(localizedType) (\(durationText)) ليوم \(eventDateText)."
                : "\(localizedType) (\(durationText)) logged for \(eventDateText)."

        case .manualOverrideSet(let toPhase, let overrideDate):
            let overrideDateText = formatter.string(from: overrideDate)
            let localizedPhase = Self.localizePhase(toPhase, isArabic: isArabic)
            return isArabic
                ? "تم تغيير يوم \(overrideDateText) إلى \(localizedPhase)."
                : "\(overrideDateText) changed to \(localizedPhase)."

        case .manualOverrideCleared(let overrideDate):
            let overrideDateText = formatter.string(from: overrideDate)
            return isArabic
                ? "تم استعادة يوم \(overrideDateText) إلى الجدول الأصلي."
                : "\(overrideDateText) restored to original schedule."

        case .legacy(_, let body):
            return body

        // Phase 3: Notification Events
        case .notificationsScheduled(let count, let dateRange):
            return isArabic
                ? "تم جدولة \(count) تنبيه للفترة \(dateRange)."
                : "\(count) notifications scheduled for \(dateRange)."

        case .notificationVerifiedForeground:
            return isArabic
                ? "تم التحقق من وصول التنبيه أثناء استخدام التطبيق."
                : "Notification delivery verified while app was open."

        case .notificationVerifiedInteraction:
            return isArabic
                ? "تم التحقق من التنبيه عند تفاعلك معه."
                : "Notification verified when you interacted with it."

        case .notificationsFailed(let count, let reason):
            return isArabic
                ? "لم يتم جدولة \(count) تنبيه. السبب: \(reason)"
                : "\(count) notification(s) could not be scheduled. Reason: \(reason)"

        // Phase 4: Reference Date Validation
        case .referenceDateCorruptionDetected(let reason):
            return isArabic
                ? "تم اكتشاف خلل في بيانات الجدول: \(reason). يرجى التحقق من جدول نوبتك."
                : "Schedule data issue detected: \(reason). Please verify your shift schedule."

        case .referenceDateRecovered(let method):
            let methodText: String
            switch method {
            case "wizard":
                methodText = isArabic ? "معالج التحقق" : "verification wizard"
            case "backup":
                methodText = isArabic ? "النسخة الاحتياطية" : "backup data"
            default:
                methodText = method
            }
            return isArabic
                ? "تم استعادة بيانات الجدول بنجاح باستخدام \(methodText)."
                : "Schedule data successfully recovered using \(methodText)."

        case .referenceDateResetRequired:
            return isArabic
                ? "لم يتمكن النظام من استعادة بيانات الجدول. يرجى إعادة إعداد نظام النوبات."
                : "Could not recover schedule data. Please re-setup your shift system."

        case .timezoneChanged(let oldTZ, let newTZ):
            return isArabic
                ? "تم اكتشاف تغيير في المنطقة الزمنية من \(oldTZ) إلى \(newTZ). تم تحديث جدول التنبيهات."
                : "Timezone changed from \(oldTZ) to \(newTZ). Notification schedule updated."

        case .systemDiagnostic:
            return isArabic
                ? "تم اكتشاف مسار برمجي غير متوقع. تم تسجيل المعلومات للتشخيص."
                : "An unexpected code path was detected. Information logged for diagnostics."
        }
    }

    /// Helper to localize ShiftEventType rawValue at display time
    private static func localizeEventType(_ rawValue: String, isArabic: Bool) -> String {
        switch rawValue {
        case "lateEntry":
            return isArabic ? "استئذان بداية دوام" : "Start Permission"
        case "earlyExit":
            return isArabic ? "استئذان نهاية دوام" : "End Permission"
        case "midShiftPermission":
            return isArabic ? "استئذان أثناء الدوام" : "Mid-Shift Permission"
        case "overtime":
            return isArabic ? "عمل إضافي" : "Overtime"
        default:
            return rawValue
        }
    }

    /// Helper to localize ShiftPhase rawValue at display time
    private static func localizePhase(_ rawValue: String, isArabic: Bool) -> String {
        switch rawValue {
        case "morning":
            return isArabic ? "دوام صباح" : "Morning Shift"
        case "evening":
            return isArabic ? "دوام عصر" : "Evening Shift"
        case "night":
            return isArabic ? "دوام ليل" : "Night Shift"
        case "off":
            return isArabic ? "يوم راحة" : "Day Off"
        case "firstOff":
            return isArabic ? "راحة (1)" : "First Off"
        case "secondOff":
            return isArabic ? "راحة (2)" : "Second Off"
        case "weekend":
            return isArabic ? "عطلة" : "Weekend"
        case "leave":
            return isArabic ? "إجازة" : "Leave"
        default:
            return rawValue
        }
    }
}

// MARK: - Source

enum SystemMessageSource: String, Codable {
    case manualLeave
    case shift
    case attendance
    case system
    case shiftEvent  // ✅ P1: Hourly permissions (late entry, early exit, overtime)
    case notification  // ✅ P3: Notification scheduling events
    case validation  // ✅ P4: Reference date validation events (Government-Grade Hardening)
}

// MARK: - Language Helper (🔒 نقطة تحكم واحدة)
// نستخدم UserDefaults مباشرة هنا لتجنب مشاكل الـ MainActor عند استخدام الموديل في الخلفية
private enum SystemMessageLanguage {

    static var isArabic: Bool {
        UserDefaults.standard.string(forKey: "app_language") == "ar"
    }

    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        // Phase 2: Use Latin digits locale for consistent number display
        formatter.locale = isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
