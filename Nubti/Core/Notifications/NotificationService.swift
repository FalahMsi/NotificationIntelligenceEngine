import Foundation
import UserNotifications
import UIKit
import Combine
import os.log

/// NotificationService
/// المحرك المركزي الذكي لإدارة الإشعارات الزمنية.
/// ✅ V3: يستخدم NotificationAdvancedConfig كمصدر وحيد للحقيقة
/// ✅ يعتمد على ShiftEngine لحساب الأوقات
/// ✅ V4: يدعم UNUserNotificationCenterDelegate لعرض الإشعارات في الـ Foreground
/// ✅ V5: يدعم Activity Log integration + AppLogger structured logging (Phase 3)
///
/// # Version History
/// - V1: UserDefaults keys (enable_punch_in, etc.) - LEGACY
/// - V2: Added permission checks, preset enforcement, advanced config
/// - V3: Unified config, 7-day lookahead, stale app warning, cross-midnight fix
/// - V4: Added UNUserNotificationCenterDelegate, foreground presentation, test verification
/// - V5: Added Activity Log integration, structured logging, error surfacing (Phase 3)
///
/// ## Current Behavior (V5)
/// - Single Source of Truth: NotificationAdvancedConfig
/// - Permission verified before scheduling
/// - Lookahead: 7 days (63 notifications max)
/// - Supports: primary/secondary offsets, exact-time, pre-day reminder
/// - Cross-midnight (overnight) shifts handled correctly
/// - Stale app warning (48h)
/// - Foreground notification presentation via delegate
/// - State-aware test notification verification
/// - Activity Log integration for user-visible notification events
/// - Structured logging via AppLogger for observability
///
// MARK: - Nubti Notification Sound (Single Source of Truth)

/// صوت الإشعار المخصص لتطبيق نوبتي
/// يستخدم الملف الصوتي المضمن في الـ Bundle
enum NubtiNotificationSound {
    /// الصوت المخصص الافتراضي لجميع إشعارات التطبيق
    static let `default` = UNNotificationSound(named: UNNotificationSoundName("nubti_notification.caf"))
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    // MARK: - Phase 3: Structured Logging (Inlined OSLog)

    /// OSLog logger for notification events
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.duami.app",
        category: "Notifications"
    )

    // MARK: - Test Notification State (In-Memory Only)

    /// حالة التحقق من الإشعار التجريبي
    enum TestNotificationState {
        case idle
        case sending
        case verified      // تم التحقق عبر willPresent أو didReceive
        case failed(String) // فشل الجدولة
        case timeout       // انتهت المهلة بدون تأكيد
    }

    /// حالة الإشعار التجريبي الحالية (in-memory only - no persistence)
    @Published private(set) var testNotificationState: TestNotificationState = .idle

    /// معرف الإشعار التجريبي
    private let testNotificationID = "duami.test_notification"

    /// مؤقت انتهاء المهلة
    private var testTimeoutTimer: Timer?

    /// callback للإشعار بنتيجة التحقق
    var onTestNotificationVerified: (() -> Void)?

    // MARK: - Phase 3: Scheduling Result Tracking

    /// عداد للإشعارات التي فشلت في الجدولة (يُصفّر مع كل rebuild)
    private var schedulingFailureCount: Int = 0

    /// آخر خطأ حدث أثناء الجدولة
    private var lastSchedulingError: String?

    /// تاريخ أول إشعار مجدول (للتقرير)
    private var firstScheduledDate: Date?

    /// تاريخ آخر إشعار مجدول (للتقرير)
    private var lastScheduledDate: Date?

    private override init() {
        super.init()
        // تعيين الـ delegate عند الإنشاء
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// يُستدعى عندما يصل إشعار والتطبيق في الـ Foreground
    /// هذا هو المفتاح لإظهار الإشعارات أثناء استخدام التطبيق
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier

        // Phase 3: Structured logging
        Self.logger.info("Notification verified [id=\(identifier), source=foreground]")

        // التحقق من الإشعار التجريبي
        if identifier == testNotificationID {
            DispatchQueue.main.async { [weak self] in
                self?.handleTestNotificationVerified()
            }
        }

        // Phase 3: Log verification to Activity Log (foreground = reliable signal)
        // Only log for shift notifications (not test or stale warnings)
        if identifier.hasPrefix(idPrefix) {
            DispatchQueue.main.async {
                let message = MessageFactory.makeNotificationVerifiedForeground()
                MessagesStore.shared.add(message)
            }
        }

        // عرض الإشعار مع banner + sound حتى في الـ Foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// يُستدعى عندما يتفاعل المستخدم مع الإشعار (tap)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier

        // Phase 3: Structured logging
        Self.logger.info("Notification verified [id=\(identifier), source=interaction]")

        // التحقق من الإشعار التجريبي (في حالة Background)
        if identifier == testNotificationID {
            DispatchQueue.main.async { [weak self] in
                self?.handleTestNotificationVerified()
            }
        }

        // Phase 3: Log verification to Activity Log (user interaction = confirmed delivery)
        // Only log for shift notifications (not test or stale warnings)
        if identifier.hasPrefix(idPrefix) {
            DispatchQueue.main.async {
                let message = MessageFactory.makeNotificationVerifiedInteraction()
                MessagesStore.shared.add(message)
            }
        }

        completionHandler()
    }

    /// معالجة التحقق الناجح من الإشعار التجريبي
    private func handleTestNotificationVerified() {
        // إلغاء مؤقت الـ timeout
        testTimeoutTimer?.invalidate()
        testTimeoutTimer = nil

        // تحديث الحالة
        testNotificationState = .verified

        // استدعاء الـ callback
        onTestNotificationVerified?()

        // Phase 3: Structured logging
        Self.logger.info("Test notification VERIFIED via delegate")
    }

    // MARK: - Language / Locale

    private var languageCode: String {
        UserDefaults.standard.string(forKey: "app_language") ?? "ar"
    }

    private var isArabic: Bool { languageCode == "ar" }

    private var appLocale: Locale {
        // Phase 2: Use Latin digits locale for consistent number display
        isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
    }

    private var rtlMark: String { "\u{200F}" }
    private var ltrMark: String { "\u{200E}" }

    private func directional(_ text: String) -> String {
        (isArabic ? rtlMark : ltrMark) + text
    }

    // MARK: - Calendar

    private static let calendarBase: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    private var calendar: Calendar {
        var cal = Self.calendarBase
        cal.locale = appLocale
        return cal
    }

    // MARK: - Identifiers

    private let idPrefix = "duami.shift."

    /// V3: Extended lookahead from 2 to 7 days
    /// Notification budget: 9 per day × 7 days = 63 (under iOS 64 limit)
    private let scheduleLookAheadDays = 7

    /// V3: Increased max requests to support 7-day lookahead
    /// 9 per day (entry×3 + presence×2 + exit×2 + preday×1 + buffer×1)
    private let maxRequestsPerRebuild = 63

    // MARK: - Presence Policy

    /// بصمات التواجد (بالدقائق من بداية الدوام)
    /// يمكنك تعديلها أو جعلها تعتمد على النظام لاحقاً
    private let presenceOffsetsMinutes: [Int] = [120]

    // MARK: - Authorization & Permission Status (V2)

    /// حالة صلاحية الإشعارات الحالية
    /// يتم تحديثها عند التحقق من الصلاحيات
    enum PermissionStatus: String {
        case authorized = "authorized"
        case denied = "denied"
        case notDetermined = "notDetermined"
        case provisional = "provisional"
        case unknown = "unknown"
    }

    /// آخر حالة صلاحية معروفة (للاستخدام في واجهة الإعدادات)
    private(set) var lastKnownPermissionStatus: PermissionStatus = .unknown

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                self?.lastKnownPermissionStatus = granted ? .authorized : .denied
                let status = granted ? "🔔 Permission Granted" : "🔕 Permission Denied"
                Self.logger.info("\(status)")
            }
    }

    /// التحقق من حالة الصلاحيات قبل الجدولة (V2)
    /// - Returns: true إذا كانت الصلاحيات ممنوحة
    private func verifyPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized:
            lastKnownPermissionStatus = .authorized
            return true
        case .denied:
            lastKnownPermissionStatus = .denied
            Self.logger.warning("Permission denied - skipping scheduling")
            return false
        case .notDetermined:
            lastKnownPermissionStatus = .notDetermined
            Self.logger.warning("Permission not determined - skipping scheduling")
            return false
        case .provisional:
            lastKnownPermissionStatus = .provisional
            return true // Provisional still allows notifications
        case .ephemeral:
            lastKnownPermissionStatus = .authorized
            return true
        @unknown default:
            lastKnownPermissionStatus = .unknown
            return false
        }
    }

    /// التحقق من حالة الصلاحيات (للاستخدام في واجهة المستخدم)
    func checkPermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status: PermissionStatus
            switch settings.authorizationStatus {
            case .authorized: status = .authorized
            case .denied: status = .denied
            case .notDetermined: status = .notDetermined
            case .provisional: status = .provisional
            case .ephemeral: status = .authorized
            @unknown default: status = .unknown
            }
            self?.lastKnownPermissionStatus = status
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }

    // MARK: - Core Engine

    @MainActor
    func rebuildShiftNotifications(
        context: ShiftContext,
        manualOverrides: [String: ShiftPhase]
    ) {
        // V2: التحقق من الصلاحيات أولاً قبل الجدولة
        Task {
            let hasPermission = await verifyPermissionStatus()
            guard hasPermission else {
                Self.logger.warning("Skipping rebuild - no permission")
                return
            }

            await performScheduling(context: context, manualOverrides: manualOverrides)
        }
    }

    /// تنفيذ الجدولة الفعلية بعد التحقق من الصلاحيات
    private func performScheduling(
        context: ShiftContext,
        manualOverrides: [String: ShiftPhase]
    ) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                let now = Date()

                self.removePendingShiftNotifications {
                    let startOfToday = self.calendar.startOfDay(for: now)

                    // Phase 3: Reset tracking counters
                    self.schedulingFailureCount = 0
                    self.lastSchedulingError = nil
                    self.firstScheduledDate = nil
                    self.lastScheduledDate = nil

                    // توليد الجدول الزمني للأيام القادمة
                    let timeline = ShiftEngine.shared.generateTimeline(
                        systemID: context.systemID,
                        context: context,
                        from: startOfToday,
                        days: self.scheduleLookAheadDays
                    )

                    // V3: جدولة الإشعارات لجميع أيام العمل القادمة (7 أيام)
                    var totalScheduled = 0
                    let workItems = self.getAllRelevantWorkItems(
                        from: timeline,
                        context: context,
                        manualOverrides: manualOverrides,
                        now: now
                    )

                    // Phase 3: Track date range for Activity Log
                    if let firstItem = workItems.first {
                        self.firstScheduledDate = firstItem.dayDate
                    }
                    if let lastItem = workItems.last {
                        self.lastScheduledDate = lastItem.dayDate
                    }

                    for item in workItems {
                        guard totalScheduled < self.maxRequestsPerRebuild else { break }
                        let count = self.scheduleForItem(
                            date: item.dayDate,
                            phase: item.phase,
                            context: context,
                            now: now
                        )
                        totalScheduled += count
                    }

                    // V3: جدولة تنبيه "التطبيق قديم" (48 ساعة)
                    self.scheduleStaleAppWarning()

                    // V2/Phase 5: جدولة تذكير قبل اليوم (12 ساعة) إذا كان مفعّلاً
                    self.schedulePreDayReminderIfEnabled(
                        timeline: timeline,
                        context: context,
                        manualOverrides: manualOverrides,
                        now: now
                    )

                    // Phase 3: Structured logging
                    let dateRange = self.formatDateRangeForLog()
                    Self.logger.info("Notification batch scheduled [count=\(totalScheduled), dateRange=\(dateRange)]")

                    // Phase 3: Log to Activity Log
                    DispatchQueue.main.async {
                        self.logSchedulingResultToActivityLog(
                            scheduledCount: totalScheduled,
                            failedCount: self.schedulingFailureCount
                        )
                    }

                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Pick Work Days

    private struct NextWorkItem {
        let dayDate: Date
        let phase: ShiftPhase
    }

    /// V3: جمع جميع أيام العمل القادمة في فترة الـ Lookahead
    private func getAllRelevantWorkItems(
        from timeline: ShiftTimeline,
        context: ShiftContext,
        manualOverrides: [String: ShiftPhase],
        now: Date
    ) -> [NextWorkItem] {
        var items: [NextWorkItem] = []

        for item in timeline.items {
            let dayDate = calendar.startOfDay(for: item.date)
            let key = dayKey(for: dayDate)

            // الأولوية للتعديل اليدوي
            let phase = manualOverrides[key] ?? item.phase

            // نتجاوز أيام الراحة
            guard phase.isCountedAsWorkDay else { continue }

            // حساب الوقت الدقيق
            guard let times = resolvePunchTimes(
                for: dayDate,
                phase: phase,
                context: context
            ) else { continue }

            // إذا كان وقت الانتهاء في المستقبل، نضيفه للقائمة
            if times.end > now {
                items.append(NextWorkItem(dayDate: dayDate, phase: phase))
            }
        }

        return items
    }

    /// Legacy: للتوافق مع الكود القديم
    private func pickNextRelevantWorkItem(
        from timeline: ShiftTimeline,
        context: ShiftContext,
        manualOverrides: [String: ShiftPhase],
        now: Date
    ) -> NextWorkItem? {
        return getAllRelevantWorkItems(
            from: timeline,
            context: context,
            manualOverrides: manualOverrides,
            now: now
        ).first
    }

    // MARK: - Stale App Warning (V3)

    private let staleAppWarningID = "duami.stale_app_warning"

    /// جدولة تنبيه "التطبيق قديم" - يُطلق بعد 48 ساعة إذا لم يُفتح التطبيق
    private func scheduleStaleAppWarning() {
        // إلغاء أي تنبيه سابق
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [staleAppWarningID]
        )

        let content = UNMutableNotificationContent()
        content.title = directional(isArabic ? "تذكير نوبتي" : "Nubti Reminder")
        content.body = directional(isArabic
            ? "افتح التطبيق للحفاظ على دقة التنبيهات"
            : "Open the app to keep notifications accurate"
        )
        content.sound = NubtiNotificationSound.default

        // 48 ساعة = 172800 ثانية
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 48 * 60 * 60,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: staleAppWarningID,
            content: content,
            trigger: trigger
        )

        // V4/V5: إضافة error callback with structured logging
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Self.logger.error("Stale app warning failed to schedule [error=\(error.localizedDescription)]")
            } else {
                Self.logger.info("Stale app warning scheduled (48h)")
            }
        }
    }

    // MARK: - Scheduler (Single Day)

    private func scheduleForItem(
        date: Date,
        phase: ShiftPhase,
        context: ShiftContext,
        now: Date
    ) -> Int {

        guard let times = resolvePunchTimes(
            for: date,
            phase: phase,
            context: context
        ) else { return 0 }

        var scheduled = 0

        let isActive = now >= times.start && now < times.end
        let isUpcoming = now < times.start

        // V3: قراءة جميع الإعدادات من المصدر الموحد (Single Source of Truth)
        let config = NotificationConfigStore.shared.load()

        // V3: استخدام الإعدادات الموحدة بدلاً من مفاتيح UserDefaults القديمة
        let enablePunchIn = config.entry.enabled
        let enablePresence = config.presence.enabled
        let enablePunchOut = config.exit.enabled

        // V3: استخدام الـ offset من الإعدادات الموحدة
        let effectiveOffset = config.entry.primaryOffset

        // V3: الإعدادات المتقدمة (للتوافق مع الكود الموجود)
        let advancedConfig = config

        // 🟢 Check-in (دخول) - V2: تفعيل فقط إذا كان الـ Preset يسمح + تطبيق الـ Offset
        if isUpcoming && enablePunchIn {
            // حساب وقت التنبيه المسبق (قبل بداية الدوام بـ X دقيقة)
            let reminderTime = calendar.date(byAdding: .minute, value: -effectiveOffset, to: times.start) ?? times.start

            let event: SystemEvent = .punchReminder(type: .checkIn, minutesBefore: effectiveOffset)
            if scheduleEventIfFuture(
                event: event,
                id: idPrefix + "in.\(times.start.timeIntervalSince1970)",
                date: reminderTime
            ) {
                scheduled += 1
            }

            // V2/Phase 4: تنبيه ثانوي للدخول (اختياري)
            if advancedConfig.entry.secondaryEnabled && scheduled < maxRequestsPerRebuild {
                let secondaryOffset = advancedConfig.entry.secondaryOffset
                let secondaryTime = calendar.date(byAdding: .minute, value: -secondaryOffset, to: times.start) ?? times.start

                // التأكد من أن الوقت الثانوي مختلف عن الأساسي
                if secondaryTime != reminderTime {
                    let secondaryEvent: SystemEvent = .punchReminder(type: .checkIn, minutesBefore: secondaryOffset)
                    if scheduleEventIfFuture(
                        event: secondaryEvent,
                        id: idPrefix + "in.secondary.\(times.start.timeIntervalSince1970)",
                        date: secondaryTime
                    ) {
                        scheduled += 1
                    }
                }
            }

            // V2/Phase 4: تنبيه في الوقت المحدد بالضبط (اختياري)
            if advancedConfig.entry.atExactTime && scheduled < maxRequestsPerRebuild {
                // فقط إذا كان مختلفاً عن التنبيه الأساسي (أي الـ offset ليس 0)
                if effectiveOffset > 0 {
                    let exactEvent: SystemEvent = .punchReminder(type: .checkIn, minutesBefore: 0)
                    if scheduleEventIfFuture(
                        event: exactEvent,
                        id: idPrefix + "in.exact.\(times.start.timeIntervalSince1970)",
                        date: times.start
                    ) {
                        scheduled += 1
                    }
                }
            }
        }

        // 🟠 Presence (تواجد) - V2: تفعيل فقط إذا كان الـ Preset يسمح
        if enablePresence {
            // V2/Phase 4: استخدام الـ offset من الإعدادات المتقدمة
            let presenceOffset = advancedConfig.presence.primaryOffset
            if let presenceTime = calendar.date(byAdding: .minute, value: presenceOffset, to: times.start),
               presenceTime > Date() && presenceTime < times.end && scheduled < maxRequestsPerRebuild {

                let event: SystemEvent = .punchReminder(type: .presence, minutesBefore: 0)
                if scheduleEventIfFuture(
                    event: event,
                    id: idPrefix + "presence.\(presenceTime.timeIntervalSince1970)",
                    date: presenceTime
                ) {
                    scheduled += 1
                }

                // V2/Phase 4: تنبيه تواجد ثانوي (متابعة)
                if advancedConfig.presence.secondaryEnabled && scheduled < maxRequestsPerRebuild {
                    let secondaryDelay = advancedConfig.presence.secondaryDelay
                    if let secondaryTime = calendar.date(byAdding: .minute, value: secondaryDelay, to: presenceTime),
                       secondaryTime > Date() && secondaryTime < times.end {

                        let secondaryEvent: SystemEvent = .punchReminder(type: .presence, minutesBefore: 0)
                        if scheduleEventIfFuture(
                            event: secondaryEvent,
                            id: idPrefix + "presence.secondary.\(secondaryTime.timeIntervalSince1970)",
                            date: secondaryTime
                        ) {
                            scheduled += 1
                        }
                    }
                }
            }
        }

        // 🔴 Check-out (خروج) - V2: تفعيل فقط إذا كان الـ Preset يسمح
        if (isActive || isUpcoming) && enablePunchOut && scheduled < maxRequestsPerRebuild {

            // V2/Phase 4: تنبيه مسبق قبل نهاية الدوام (اختياري)
            let advanceWarning = advancedConfig.exit.advanceWarning
            if advanceWarning > 0 {
                if let warningTime = calendar.date(byAdding: .minute, value: -advanceWarning, to: times.end),
                   warningTime > Date() {
                    let warningEvent: SystemEvent = .punchReminder(type: .checkOut, minutesBefore: advanceWarning)
                    if scheduleEventIfFuture(
                        event: warningEvent,
                        id: idPrefix + "out.warning.\(times.end.timeIntervalSince1970)",
                        date: warningTime
                    ) {
                        scheduled += 1
                    }
                }
            }

            // V2/Phase 4: تنبيه في الوقت المحدد بالضبط
            if advancedConfig.exit.atExactTime && scheduled < maxRequestsPerRebuild {
                let event: SystemEvent = .punchReminder(type: .checkOut, minutesBefore: 0)
                if scheduleEventIfFuture(
                    event: event,
                    id: idPrefix + "out.\(times.end.timeIntervalSince1970)",
                    date: times.end
                ) {
                    scheduled += 1
                }
            }
        }

        return scheduled
    }

    // MARK: - Pre-Day Reminder (V2/Phase 5 - REFACTORED)

    // ⚠️ ARCHITECTURAL RULE (PERMANENT - DO NOT CIRCUMVENT):
    // Timeline-based date matching MUST NOT be used for notification semantics.
    //
    // FORBIDDEN PATTERN (removed in Phase 5 Fix):
    // ```swift
    // timeline.items.first(where: { calendar.isDate($0.date, inSameDayAs: tomorrow) })
    // ```
    //
    // REQUIRED PATTERN (implemented below):
    // ```swift
    // UpcomingShiftResolver().resolve(referenceTime: now, context: context)
    // ```
    //
    // WHY: Night shifts that START today but END tomorrow were incorrectly labeled.
    // The resolver correctly finds shifts by comparing START times.

    /// جدولة تذكير قبل اليوم (12 ساعة قبل بداية الدوام) إذا كان مفعّلاً
    /// Phase 5 Fix: Uses UpcomingShiftResolver instead of timeline-based date matching
    private func schedulePreDayReminderIfEnabled(
        timeline: ShiftTimeline,
        context: ShiftContext,
        manualOverrides: [String: ShiftPhase],
        now: Date
    ) {
        // التحقق من تفعيل الميزة
        let config = NotificationConfigStore.shared.load()
        guard config.global.preDayReminderEnabled else { return }

        // Phase 5 Fix: Use UpcomingShiftResolver as single source of truth
        // This replaces the old timeline-based date matching which caused the night shift bug
        let resolver = UpcomingShiftResolver()
        guard let upcomingShift = resolver.resolve(
            referenceTime: now,
            context: context,
            manualOverrides: manualOverrides
        ) else {
            Self.logger.info("Pre-day reminder: No upcoming shift found in lookahead window")
            return
        }

        // Calculate reminder trigger time (N hours before shift START)
        // SEMANTIC RULE: Reminder timing is ALWAYS calculated from shift START, never END
        // Uses configurable hours from user settings (default: 12)
        let reminderHours = config.global.preDayReminderHours
        guard let reminderTime = calendar.date(
            byAdding: .hour,
            value: -reminderHours,
            to: upcomingShift.startTime
        ) else {
            Self.logger.warning("Pre-day reminder: Failed to calculate reminder time")
            return
        }

        // Ensure reminder time is in the future
        guard reminderTime > now else {
            Self.logger.info("Pre-day reminder: Trigger time already passed (\(reminderTime) <= \(now))")
            return
        }

        // Build notification content with correct day label
        // Phase 5 Fix: Day label comes from resolver, not hardcoded "tomorrow"
        let event: SystemEvent = .preDayReminder(
            isWorkDay: true,
            shiftStart: upcomingShift.startTime
        )
        let id = idPrefix + "preday.\(upcomingShift.shiftDate.timeIntervalSince1970)"

        // Schedule with resolver data for message template
        _ = schedulePreDayEventWithResolverData(
            event: event,
            id: id,
            date: reminderTime,
            upcomingShift: upcomingShift
        )

        Self.logger.info("Pre-day reminder scheduled [triggerTime=\(reminderTime), shiftStart=\(upcomingShift.startTime), dayLabel=\(upcomingShift.dayLabel.rawValue)]")
    }

    /// Schedule pre-day event with resolver data for correct message content
    /// Phase 5 Fix: Passes dayLabel and shiftLabel to MessageData
    private func schedulePreDayEventWithResolverData(
        event: SystemEvent,
        id: String,
        date: Date,
        upcomingShift: UpcomingShiftResolver.UpcomingShiftInfo
    ) -> Bool {
        guard date > Date() else { return false }

        let title = directional(resolveTitle(for: event))

        // Phase 5 Fix: Build body with resolver data (dynamic day label)
        let body = buildPreDayReminderBody(upcomingShift: upcomingShift)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = directional(body)
        content.sound = NubtiNotificationSound.default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Self.logger.error("Pre-day reminder failed to schedule [id=\(id), error=\(error.localizedDescription)]")
            }
        }
        return true
    }

    /// Build pre-day reminder body with correct day label from resolver
    /// Phase 5 Fix: Uses UpcomingShiftResolver.DayLabel instead of hardcoded "tomorrow"
    private func buildPreDayReminderBody(upcomingShift: UpcomingShiftResolver.UpcomingShiftInfo) -> String {
        var data = MessageData(
            punchType: "",
            minutes: 0,
            leaveType: "",
            fromDate: "",
            toDate: ""
        )
        data.isWorkDay = true
        data.shiftStartTime = upcomingShift.formattedStartTime
        data.dayLabel = upcomingShift.dayLabel  // Phase 5 Fix: Dynamic day label
        data.shiftLabel = upcomingShift.shiftLabel  // Phase 5 Fix: Shift type label

        return MessageTemplate.preDayReminder.resolve(using: data)
    }

    // MARK: - Shift Times (SOURCE OF TRUTH 🧠)

    /// هذه الدالة هي الجسر بين الإشعارات والعقل الجديد.
    /// تستخدم ShiftEngine لحساب الوقت بدقة.
    private func resolvePunchTimes(
        for dayDate: Date,
        phase: ShiftPhase,
        context: ShiftContext
    ) -> (start: Date, end: Date)? {

        // 1. استخدام المحرك المركزي لحساب الوقت الأساسي
        guard let exactTimes = ShiftEngine.shared.calculateExactShiftTimes(
            context: context,
            for: dayDate,
            phase: phase
        ) else {
            return nil
        }
        
        let checkIn = exactTimes.start
        let checkOut = exactTimes.end

        // 2. تطبيق قواعد المرونة (Flexibility) لتمديد وقت الخروج
        if context.flexibility.isFlexibleTime {
            let displacement = calculateDisplacement(for: dayDate)
            // إضافة وقت التأخير لوقت الخروج
            let finalEnd = calendar.date(byAdding: .minute, value: displacement, to: checkOut) ?? checkOut
            return (checkIn, finalEnd)
        }

        return (checkIn, checkOut)
    }

    /// حساب وقت الإزاحة (التأخير + العمل الإضافي)
    private func calculateDisplacement(for date: Date) -> Int {
        let events = ShiftEventStore.shared.events(for: date)
        return events.reduce(0) {
            guard !$1.isIgnored else { return $0 }
            if $1.type == .lateEntry || $1.type == .overtime {
                return $0 + $1.durationMinutes
            }
            return $0
        }
    }

    // MARK: - Presence Builder

    private func buildPresenceDates(
        shiftStart: Date,
        shiftEnd: Date
    ) -> [Date] {
        presenceOffsetsMinutes.compactMap {
            calendar.date(byAdding: .minute, value: $0, to: shiftStart)
        }
        .filter { $0 > Date() && $0 < shiftEnd }
    }

    // MARK: - SystemEvent + MessageTemplate Bridge

    private func resolveBody(for event: SystemEvent) -> String {
        switch event {

        case .punchReminder(let type, let minutesBefore):
            let data = MessageData(
                punchType: type.title,
                minutes: minutesBefore,
                leaveType: "",
                fromDate: "",
                toDate: ""
            )
            return MessageTemplate.punchReminder.resolve(using: data)

        case .manualLeaveRegistered(_, let typeTitle, let startDate, let endDate):
            let df = DateFormatter()
            df.locale = appLocale
            df.dateStyle = .medium
            df.timeStyle = .none

            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: typeTitle,
                fromDate: df.string(from: startDate),
                toDate: df.string(from: endDate)
            )
            return MessageTemplate.manualLeaveRegistered.resolve(using: data)

        case .manualLeaveStarting(_, let typeTitle):
            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: typeTitle,
                fromDate: "",
                toDate: ""
            )
            return MessageTemplate.manualLeaveStarting.resolve(using: data)

        case .manualLeaveEnding(_, let typeTitle):
            let data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: typeTitle,
                fromDate: "",
                toDate: ""
            )
            return MessageTemplate.manualLeaveEnding.resolve(using: data)

        case .preDayReminder(let isWorkDay, let shiftStart):
            let tf = DateFormatter()
            // Phase 2: Use explicit 24-hour format with Latin digits
            tf.locale = Locale(identifier: "en_US_POSIX")
            tf.dateFormat = "HH:mm"

            let shiftTime = shiftStart.map { tf.string(from: $0) } ?? ""
            var data = MessageData(
                punchType: "",
                minutes: 0,
                leaveType: "",
                fromDate: "",
                toDate: ""
            )
            data.isWorkDay = isWorkDay
            data.shiftStartTime = shiftTime
            return MessageTemplate.preDayReminder.resolve(using: data)
        }
    }

    private func resolveTitle(for event: SystemEvent) -> String {
        switch event {
        case .punchReminder:
            return MessageTemplate.punchReminder.title
        case .preDayReminder:
            return MessageTemplate.preDayReminder.title
        case .manualLeaveRegistered:
            return MessageTemplate.manualLeaveRegistered.title
        case .manualLeaveStarting:
            return MessageTemplate.manualLeaveStarting.title
        case .manualLeaveEnding:
            return MessageTemplate.manualLeaveEnding.title
        }
    }

    // MARK: - Scheduling

    private func scheduleEventIfFuture(
        event: SystemEvent,
        id: String,
        date: Date
    ) -> Bool {

        guard date > Date() else { return false }

        let title = directional(resolveTitle(for: event))
        let body = directional(resolveBody(for: event))

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = NubtiNotificationSound.default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        // V5: إضافة error callback مع سياق كامل + tracking
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                // Phase 3: Track failure
                self?.schedulingFailureCount += 1
                self?.lastSchedulingError = error.localizedDescription

                // Phase 3: Structured logging with context
                let formatter = ISO8601DateFormatter()
                let dateStr = formatter.string(from: date)
                Self.logger.error("Notification scheduling failed [id=\(id), triggerDate=\(dateStr), error=\(error.localizedDescription)]")
            } else {
                // Phase 3: Log successful scheduling
                let formatter = ISO8601DateFormatter()
                let dateStr = formatter.string(from: date)
                Self.logger.info("Notification scheduled [id=\(id), triggerDate=\(dateStr), type=shift]")
            }
        }
        return true
    }

    // MARK: - Cleanup

    private func removePendingShiftNotifications(
        completion: @escaping () -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(self.idPrefix) }

            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            completion()
        }
    }

    // MARK: - Helpers

    /// Generates a canonical day key using DayKeyGenerator.
    /// Format: YYYY-MM-DD (zero-padded) - e.g., "2026-01-05" not "2026-1-5"
    ///
    /// - Important: This MUST use DayKeyGenerator to ensure consistency with
    ///              UserShift's manual override storage and UpcomingShiftResolver's lookup.
    ///              Format mismatch causes manual overrides to be SILENTLY IGNORED.
    ///
    /// - SeeAlso: DayKeyGenerator.swift (Single Source of Truth)
    private func dayKey(for date: Date) -> String {
        DayKeyGenerator.key(for: date, calendar: calendar)
    }

    // MARK: - Public

    func cancelAllShiftNotifications() {
        removePendingShiftNotifications {}
    }

    // MARK: - Test Notification (V4: State-Aware Verification)

    /// إرسال تنبيه تجريبي للتحقق من عمل الإشعارات
    /// V4: يستخدم state machine للتحقق الفعلي من وصول الإشعار
    func sendTestNotification() {
        // 1. تحديث الحالة إلى "جاري الإرسال"
        testNotificationState = .sending

        // 2. إلغاء أي مؤقت سابق
        testTimeoutTimer?.invalidate()
        testTimeoutTimer = nil

        // 3. إلغاء أي إشعار تجريبي سابق لتجنب التكرار
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [testNotificationID]
        )

        let content = UNMutableNotificationContent()
        content.title = directional(isArabic ? "تنبيه تجريبي" : "Test Notification")
        content.body = directional(isArabic
            ? "التنبيهات تعمل بشكل صحيح!"
            : "Notifications are working correctly!"
        )
        content.sound = NubtiNotificationSound.default

        // إرسال بعد 3 ثواني
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)

        let request = UNNotificationRequest(
            identifier: testNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    // Phase 3: Structured logging
                    Self.logger.error("Test notification failed to schedule [error=\(error.localizedDescription)]")
                    self?.testNotificationState = .failed(error.localizedDescription)
                    return
                }

                // Phase 3: Structured logging
                Self.logger.info("Test notification scheduled, waiting for verification...")

                // 4. بدء مؤقت الـ timeout (5 ثواني بعد الجدولة = 8 ثواني إجمالي)
                // الإشعار يُطلق بعد 3 ثواني، نعطي 5 ثواني إضافية للوصول
                self?.startTestTimeout()
            }
        }
    }

    /// بدء مؤقت انتهاء المهلة للإشعار التجريبي
    private func startTestTimeout() {
        testTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }

                // إذا لم نتلقَ تأكيد من الـ delegate، نعتبره timeout
                if case .sending = self.testNotificationState {
                    // Phase 3: Structured logging
                    Self.logger.warning("Test notification timeout - no delegate callback received")
                    self.testNotificationState = .timeout
                }
            }
        }
    }

    /// إعادة تعيين حالة الإشعار التجريبي
    func resetTestNotificationState() {
        testTimeoutTimer?.invalidate()
        testTimeoutTimer = nil
        testNotificationState = .idle
    }

    // MARK: - Pending Notifications Info (V3/Phase 1)

    /// جلب عدد الإشعارات المجدولة
    func getPendingNotificationsCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let shiftNotifications = requests.filter { $0.identifier.hasPrefix(self.idPrefix) }
            DispatchQueue.main.async {
                completion(shiftNotifications.count)
            }
        }
    }

    /// جلب أقرب 3 إشعارات مجدولة
    func getUpcomingNotifications(limit: Int = 3, completion: @escaping ([(title: String, date: Date)]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let shiftNotifications = requests
                .filter { $0.identifier.hasPrefix(self.idPrefix) }
                .compactMap { request -> (title: String, date: Date)? in
                    guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                          let date = trigger.nextTriggerDate() else { return nil }
                    return (request.content.title, date)
                }
                .sorted { $0.date < $1.date }
                .prefix(limit)

            DispatchQueue.main.async {
                completion(Array(shiftNotifications))
            }
        }
    }

    // MARK: - Phase 3: Activity Log Integration

    /// تسجيل نتيجة الجدولة في Activity Log
    /// يُستدعى بعد اكتمال جدولة الدفعة
    @MainActor
    private func logSchedulingResultToActivityLog(scheduledCount: Int, failedCount: Int) {
        // Don't log if nothing was scheduled (e.g., no work days in range)
        guard scheduledCount > 0 || failedCount > 0 else { return }

        if failedCount > 0 {
            // Log failures to Activity Log (user-visible)
            let message = MessageFactory.makeNotificationsFailed(
                failedCount: failedCount,
                reason: lastSchedulingError ?? "Unknown"
            )
            MessagesStore.shared.add(message)

            // Also log batch with failures for observability
            Self.logger.warning("Notification batch completed with failures [success=\(scheduledCount), failed=\(failedCount)]")
        } else if scheduledCount > 0 {
            // Log success to Activity Log (user-visible)
            guard let startDate = firstScheduledDate,
                  let endDate = lastScheduledDate else { return }

            let message = MessageFactory.makeNotificationsScheduled(
                count: scheduledCount,
                startDate: startDate,
                endDate: endDate
            )
            MessagesStore.shared.add(message)
        }
    }

    /// تنسيق نطاق التواريخ للتسجيل
    private func formatDateRangeForLog() -> String {
        guard let start = firstScheduledDate,
              let end = lastScheduledDate else {
            return "N/A"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}
