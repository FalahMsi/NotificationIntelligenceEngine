import Foundation

/// MessageFactory
/// المصنع الوحيد لتوليد رسائل النظام من الأحداث.
/// يقوم بتحويل SystemEvent (الخام) إلى SystemMessage (القابلة للعرض والتخزين).
struct MessageFactory {

    /// Converts a SystemEvent to a SystemMessage for storage in Updates.
    /// ⛔️ IMPORTANT: Only leave-related events are supported.
    /// Punch reminders are iOS notifications only — they MUST NOT go through MessageFactory.
    static func make(from event: SystemEvent) -> SystemMessage {

        switch event {

        // MARK: - Punch Reminders & Pre-Day Reminders — ARCHITECTURAL BARRIER
        // These are for iOS Notification Center ONLY.
        // NotificationService uses resolveBody/resolveTitle directly.
        // If these cases are ever reached, it indicates a programming error - return a
        // diagnostic message instead of crashing, to maintain app stability.
        case .punchReminder(let type, let offsetMinutes):
            // Log the error for debugging
            assertionFailure("MessageFactory.make(from:) must not be called with .punchReminder. Punch reminders are iOS notifications only.")

            // Return a safe fallback message instead of crashing
            // Use punchReminder template with the provided data
            let data = MessageData(
                punchType: type.rawValue,
                minutes: offsetMinutes,
                leaveType: "",
                fromDate: "",
                toDate: ""
            )
            return build(
                .punchReminder,
                data,
                sourceType: .system,
                sourceID: nil
            )

        case .preDayReminder(let isWorkDay, let shiftStart):
            // Log the error for debugging
            assertionFailure("MessageFactory.make(from:) must not be called with .preDayReminder. Pre-day reminders are iOS notifications only.")

            // Format shift start time if available
            let shiftStartTime: String
            if let start = shiftStart {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                shiftStartTime = formatter.string(from: start)
            } else {
                shiftStartTime = ""
            }

            // Return a safe fallback message instead of crashing
            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: "",
                fromDate: "",
                toDate: "",
                isWorkDay: isWorkDay,
                shiftStartTime: shiftStartTime
            )
            return build(
                .preDayReminder,
                data,
                sourceType: .system,
                sourceID: nil
            )

        // MARK: - Manual Leave

        case .manualLeaveRegistered(let leaveID, let typeTitle, let startDate, let endDate):

            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: typeTitle,
                fromDate: formatDate(startDate),
                toDate: formatDate(endDate)
            )

            return build(
                .manualLeaveRegistered,
                data,
                sourceType: .manualLeave,
                sourceID: leaveID
            )

        case .manualLeaveStarting(let leaveID, let typeTitle):

            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: typeTitle,
                fromDate: "",
                toDate: ""
            )

            return build(
                .manualLeaveStarting,
                data,
                sourceType: .manualLeave,
                sourceID: leaveID
            )

        case .manualLeaveEnding(let leaveID, let typeTitle):

            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: typeTitle,
                fromDate: "",
                toDate: ""
            )

            return build(
                .manualLeaveEnding,
                data,
                sourceType: .manualLeave,
                sourceID: leaveID
            )
        }
    }

    // MARK: - Builder

    /// يقوم ببناء الرسالة وحل النصوص فوراً
    private static func build(
        _ template: MessageTemplate,
        _ data: MessageData,
        sourceType: SystemMessageSource,
        sourceID: UUID? = nil
    ) -> SystemMessage {

        // نستخدم المُنشئ الذي يقبل النصوص المباشرة (Legacy Init)
        // لأننا قمنا بالفعل بترجمة النص هنا باستخدام Template
        SystemMessage(
            sourceType: sourceType,
            sourceID: sourceID,
            title: template.title,
            body: template.resolve(using: data),
            date: Date(),
            isRead: false
        )
    }

    // MARK: - Date Formatter (Shared & Localized)

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        // Phase 2: Use Latin digits locale for consistent number display
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        f.locale = isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    private static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Phase 3: Notification Event Messages

    /// Create a message for successful notification batch scheduling
    /// - Parameters:
    ///   - count: Number of notifications scheduled
    ///   - startDate: First notification date
    ///   - endDate: Last notification date
    /// - Returns: SystemMessage for Activity Log
    static func makeNotificationsScheduled(count: Int, startDate: Date, endDate: Date) -> SystemMessage {
        let dateRange = formatDateRange(startDate, endDate)
        return SystemMessage(
            sourceType: .notification,
            kind: .notificationsScheduled(scheduledCount: count, dateRange: dateRange)
        )
    }

    /// Create a message for notification verified in foreground
    /// - Returns: SystemMessage for Activity Log
    static func makeNotificationVerifiedForeground() -> SystemMessage {
        SystemMessage(
            sourceType: .notification,
            kind: .notificationVerifiedForeground
        )
    }

    /// Create a message for notification verified via user interaction
    /// - Returns: SystemMessage for Activity Log
    static func makeNotificationVerifiedInteraction() -> SystemMessage {
        SystemMessage(
            sourceType: .notification,
            kind: .notificationVerifiedInteraction
        )
    }

    /// Create a message for notification scheduling failures
    /// - Parameters:
    ///   - failedCount: Number of notifications that failed
    ///   - reason: User-friendly reason for failure
    /// - Returns: SystemMessage for Activity Log
    static func makeNotificationsFailed(failedCount: Int, reason: String) -> SystemMessage {
        // Localize the reason
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        let localizedReason = localizeErrorReason(reason, isArabic: isArabic)

        return SystemMessage(
            sourceType: .notification,
            kind: .notificationsFailed(failedCount: failedCount, reason: localizedReason)
        )
    }

    // MARK: - Date Range Formatter

    private static func formatDateRange(_ start: Date, _ end: Date) -> String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        let formatter = DateFormatter()
        formatter.locale = isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"

        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        return "\(startStr) - \(endStr)"
    }

    // MARK: - Error Reason Localization

    private static func localizeErrorReason(_ reason: String, isArabic: Bool) -> String {
        // Map common iOS notification errors to user-friendly messages
        let lowerReason = reason.lowercased()

        if lowerReason.contains("unauthorized") || lowerReason.contains("permission") {
            return isArabic ? "التنبيهات غير مفعّلة" : "Notifications not enabled"
        }
        if lowerReason.contains("budget") || lowerReason.contains("limit") {
            return isArabic ? "تجاوز حد التنبيهات" : "Notification limit exceeded"
        }
        if lowerReason.contains("past") || lowerReason.contains("date") {
            return isArabic ? "وقت التنبيه في الماضي" : "Notification time in past"
        }

        // Default: return a generic message
        return isArabic ? "خطأ في النظام" : "System error"
    }
}
