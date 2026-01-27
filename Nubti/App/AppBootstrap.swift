import Foundation

@MainActor
final class AppBootstrap {

    static let shared = AppBootstrap()
    private init() {}

    // MARK: - Dependencies
    private let messagesStore = MessagesStore.shared
    private let leaveStore = ManualLeaveStore.shared
    private let userShift = UserShift.shared
    private let settings = UserSettingsStore.shared

    // ✅ التقويم أصبح ديناميكياً ليتبع لغة التطبيق
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: settings.language.rawValue)
        cal.timeZone = .current
        return cal
    }

    private let lastRunKey = "app_bootstrap.last_run_day"

    // MARK: - Public
    func run() {
        let today = calendar.startOfDay(for: Date())

        // 0. Phase 4: Run data migrations (Government-Grade Hardening)
        // Migrations run every launch but are no-ops if already complete
        runDataMigrations()

        // 1. التحقق من تاريخ التشغيل (يمنع العمليات المكررة في نفس اليوم)
        if let lastRun = loadLastRunDate(),
           calendar.isDate(lastRun, inSameDayAs: today) {
            return
        }

        // 2. تنظيف رسائل البصمات القديمة (لم تعد تُولَّد)
        cleanupLegacyPunchMessages()

        // 3. معالجة أحداث اليوم (رسائل الإجازات)
        handleTodayEvents(for: today)

        // 4. إعادة جدولة التنبيهات الذكية للنوبات
        rebuildShiftNotificationsIfNeeded()

        // 5. حفظ تاريخ التشغيل الناجح
        saveLastRunDate(today)
    }

    // MARK: - Phase 4: Data Migrations (Government-Grade Hardening)

    /// تنفيذ ترحيل البيانات إذا لزم الأمر
    private func runDataMigrations() {
        // 1. DayKey format migration (zero-padding)
        let stats = DayKeyMigration.shared.migrateIfNeeded()
        if !stats.skipped && stats.keysMigrated > 0 {
            // Log to Activity Log
            messagesStore.add(
                kind: .systemNotice(
                    textAr: "تم تحديث تنسيق البيانات: \(stats.keysMigrated) مفتاح",
                    textEn: "Data format updated: \(stats.keysMigrated) keys migrated"
                ),
                sourceType: .system,
                sourceID: nil
            )
        }

        // 2. Additional migrations can be added here in the future
        // Example: MigrationRegistry.shared.runMigrationChain(...)
    }

    // MARK: - Core
    private func handleTodayEvents(for today: Date) {
        handleManualLeaves(for: today)
    }

    // MARK: - Manual Leaves Logic
    private func handleManualLeaves(for today: Date) {
        for leave in leaveStore.leaves {
            let startDay = calendar.startOfDay(for: leave.startDate)
            let endDay = calendar.startOfDay(for: leave.endDate)

            if calendar.isDate(today, inSameDayAs: startDay) {
                messagesStore.add(
                    MessageFactory.make(
                        from: .manualLeaveStarting(
                            leaveID: leave.id,
                            typeTitle: leave.type.localizedName
                        )
                    )
                )
            }

            if calendar.isDate(today, inSameDayAs: endDay) {
                messagesStore.add(
                    MessageFactory.make(
                        from: .manualLeaveEnding(
                            leaveID: leave.id,
                            typeTitle: leave.type.localizedName
                        )
                    )
                )
            }
        }
    }

    // MARK: - Legacy Cleanup
    private func cleanupLegacyPunchMessages() {
        let punchMessages = messagesStore.messages.filter { $0.sourceType == .attendance }
        for msg in punchMessages {
            messagesStore.delete(msg)
        }
    }

    // MARK: - Notification Sync
    private func rebuildShiftNotificationsIfNeeded() {
        // التأكد من أن المستخدم قد أكمل إعدادات جدول نوبته
        guard let context = userShift.shiftContext else { return }
        
        // إعادة بناء قائمة التنبيهات لضمان دقتها مع تغير الأيام أو الأنظمة
        // ✅ تم التصحيح: تمرير قائمة التعديلات اليدوية للدالة الجديدة
        NotificationService.shared.rebuildShiftNotifications(
            context: context,
            manualOverrides: userShift.allManualOverrides
        )
    }

    // MARK: - Persistence Helpers
    private func saveLastRunDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastRunKey)
    }

    private func loadLastRunDate() -> Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }
}
