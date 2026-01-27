import Foundation
import os.log

/// SystemEvent
/// توصيف الحدث فقط (بيانات خام بدون نصوص).
/// يتم تمرير هذا الحدث إلى MessageTemplate لتوليد النص النهائي.
enum SystemEvent: Sendable, Equatable {

    // MARK: - Punch Notifications

    /// تنبيه بصمة (دخول / تواجد / انصراف)
    /// - Parameters:
    ///   - type: نوع البصمة (دخول، تواجد، انصراف)
    ///   - minutesBefore: عدد الدقائق قبل الموعد (0 تعني "الآن")
    case punchReminder(
        type: PunchType,
        minutesBefore: Int
    )

    // MARK: - Pre-Day Reminder (V2/Phase 5)

    /// تذكير قبل اليوم (12 ساعة قبل بداية الدوام)
    /// - Parameters:
    ///   - isWorkDay: هل غداً يوم عمل أم إجازة
    ///   - shiftStart: وقت بداية الدوام (إن وجد)
    case preDayReminder(
        isWorkDay: Bool,
        shiftStart: Date?
    )

    // MARK: - Manual Leaves

    /// تم تسجيل إجازة جديدة
    case manualLeaveRegistered(
        leaveID: UUID,
        typeTitle: String,
        startDate: Date,
        endDate: Date
    )

    /// إجازة ستبدأ قريباً
    case manualLeaveStarting(
        leaveID: UUID,
        typeTitle: String
    )

    /// إجازة ستنتهي قريباً
    case manualLeaveEnding(
        leaveID: UUID,
        typeTitle: String
    )
}

// MARK: - 🧩 Supporting Structures (Required for NotificationService)

/// MessageData
/// حاوية بيانات بسيطة تستخدم لملء الفراغات في قوالب النصوص
struct MessageData {
    let punchType: String
    let minutes: Int
    let leaveType: String
    let fromDate: String
    let toDate: String
    // V2/Phase 5: Pre-day reminder data
    var isWorkDay: Bool = true
    var shiftStartTime: String = ""

    // MARK: - Phase 5 Fix: Dynamic Day Label (ARCHITECTURAL REQUIREMENT)
    // ⚠️ SEMANTIC RULE: This MUST come from UpcomingShiftResolver via ShiftDayLabel
    // Never hardcode "today"/"tomorrow" - always use this field for pre-day reminders
    var dayLabel: ShiftDayLabel? = nil

    // Phase 5 Fix: Shift type label for richer notifications ("صباحي" / "morning")
    var shiftLabel: String = ""
}

/// MessageTemplate
/// محرك القوالب النصية (يفصل المنطق عن النصوص ويدعم الترجمة)
enum MessageTemplate {
    case punchReminder
    case preDayReminder
    case manualLeaveRegistered
    case manualLeaveStarting
    case manualLeaveEnding

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "MessageTemplate"
    )

    // MARK: - Localized Title

    var title: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        switch self {
        case .punchReminder:
            return isArabic ? "تذكير بالبصمة ⏰" : "Punch Reminder ⏰"
        case .preDayReminder:
            return isArabic ? "تذكير قبل اليوم 🌙" : "Pre-Day Reminder 🌙"
        case .manualLeaveRegistered:
            return isArabic ? "تم تسجيل إجازة ✅" : "Leave Registered ✅"
        case .manualLeaveStarting:
            return isArabic ? "بداية الإجازة" : "Leave Starting"
        case .manualLeaveEnding:
            return isArabic ? "نهاية الإجازة" : "Leave Ending"
        }
    }

    // MARK: - Text Resolver
    
    /// توليد نص الرسالة بناءً على البيانات والقالب واللغة
    func resolve(using data: MessageData) -> String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        
        switch self {
        case .punchReminder:
            if data.minutes > 0 {
                return isArabic
                    ? "باقي \(data.minutes) دقيقة على موعد \(data.punchType)."
                    : "\(data.minutes) minutes remaining for \(data.punchType)."
            } else {
                return isArabic
                    ? "حان الآن موعد \(data.punchType)."
                    : "It is now time for \(data.punchType)."
            }

        case .preDayReminder:
            // Phase 5 Fix: Use dynamic dayLabel from UpcomingShiftResolver
            // ⚠️ ARCHITECTURAL RULE: Never hardcode "today"/"tomorrow"
            // The dayLabel is determined by comparing reminder delivery time vs shift START time
            if data.isWorkDay {
                // Use dynamic day label if available, fallback to "tomorrow" for backward compatibility
                let dayWord: String
                if let label = data.dayLabel {
                    dayWord = label.localized
                } else {
                    // ⚠️ ARCHITECTURAL WARNING: This fallback should not happen with new code path
                    // If this log appears, it means schedulePreDayReminderIfEnabled() is not using
                    // UpcomingShiftResolver correctly. Investigate immediately.
                    Self.logger.warning("Pre-day reminder using fallback 'tomorrow' - dayLabel was nil. This may indicate incorrect shift detection.")
                    dayWord = isArabic ? "غداً" : "tomorrow"
                }

                // Use shift label if available for richer message
                if !data.shiftLabel.isEmpty {
                    return isArabic
                        ? "\(dayWord) لديك دوام \(data.shiftLabel) يبدأ الساعة \(data.shiftStartTime)."
                        : "You have a \(data.shiftLabel) shift \(dayWord) starting at \(data.shiftStartTime)."
                } else {
                    return isArabic
                        ? "\(dayWord) لديك دوام يبدأ الساعة \(data.shiftStartTime)."
                        : "You have a shift \(dayWord) starting at \(data.shiftStartTime)."
                }
            } else {
                return isArabic
                    ? "غداً إجازة. استمتع بوقتك! 🌟"
                    : "Tomorrow is a leave day. Enjoy your time! 🌟"
            }

        case .manualLeaveRegistered:
            return isArabic
                ? "تم اعتماد إجازة (\(data.leaveType)) من \(data.fromDate) إلى \(data.toDate)."
                : "Leave (\(data.leaveType)) approved from \(data.fromDate) to \(data.toDate)."

        case .manualLeaveStarting:
            return isArabic
                ? "تذكير: إجازة (\(data.leaveType)) تبدأ غداً."
                : "Reminder: Your (\(data.leaveType)) leave starts tomorrow."

        case .manualLeaveEnding:
            return isArabic
                ? "تذكير: إجازة (\(data.leaveType)) تنتهي اليوم. دوامك القادم قريب."
                : "Reminder: Your (\(data.leaveType)) leave ends today."
        }
    }
}
