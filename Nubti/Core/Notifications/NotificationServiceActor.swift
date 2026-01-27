import Foundation
import os.log

/// NotificationServiceActor
/// Actor wrapper للتحكم في التزامن (Concurrency) عند جدولة الإشعارات.
/// يضمن thread-safety ويمنع race conditions عند الوصول المتزامن.
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Design Principles
/// 1. Actor provides serialized access to notification scheduling
/// 2. Safe to call from any thread/task
/// 3. Integrates with FeatureFlags for gradual rollout
/// 4. Maintains backward compatibility with existing NotificationService
///
/// ## Usage
/// ```swift
/// // New way (actor-isolated):
/// await NotificationServiceActor.shared.scheduleNotifications(context: context, overrides: overrides)
///
/// // Legacy way (still works):
/// NotificationService.shared.rebuildShiftNotifications(context: context, manualOverrides: overrides)
/// ```
actor NotificationServiceActor {

    // MARK: - Singleton
    static let shared = NotificationServiceActor()
    private init() {}

    // MARK: - Logging (Swift 6 Compatible - using os_log)
    private nonisolated static let log = OSLog(
        subsystem: "com.nubti.app",
        category: "NotificationServiceActor"
    )

    // MARK: - State

    /// هل الجدولة قيد التنفيذ حالياً؟
    private var isScheduling = false

    /// آخر وقت تم فيه جدولة الإشعارات
    private var lastScheduleTime: Date?

    /// عدد مرات الجدولة منذ بدء التطبيق
    private var scheduleCount: Int = 0

    // MARK: - Core Scheduling

    /// جدولة الإشعارات باستخدام Actor isolation
    /// - Parameters:
    ///   - context: سياق النوبة
    ///   - overrides: التعديلات اليدوية
    func scheduleNotifications(
        context: ShiftContext,
        overrides: [String: ShiftPhase]
    ) async {
        // التحقق من Feature Flag
        let useActor = await MainActor.run { FeatureFlags.USE_NOTIFICATION_ACTOR }
        guard useActor else {
            os_log("Actor disabled - falling back to legacy path", log: Self.log, type: .info)
            await scheduleLegacy(context: context, overrides: overrides)
            return
        }

        // منع الجدولة المتزامنة
        guard !isScheduling else {
            os_log("Scheduling already in progress - skipping", log: Self.log, type: .default)
            return
        }

        isScheduling = true
        defer { isScheduling = false }

        os_log("Starting notification scheduling via actor", log: Self.log, type: .info)
        let startTime = Date()

        // تنفيذ الجدولة على MainActor
        await MainActor.run {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: overrides
            )
        }

        // تحديث الإحصائيات
        lastScheduleTime = Date()
        scheduleCount += 1

        let duration = Date().timeIntervalSince(startTime)
        os_log("Scheduling completed [duration=%.2fs, totalSchedules=%d]", log: Self.log, type: .info, duration, scheduleCount)
    }

    /// إلغاء جميع الإشعارات المجدولة
    func cancelAll() async {
        os_log("Cancelling all notifications via actor", log: Self.log, type: .info)

        await MainActor.run {
            NotificationService.shared.cancelAllShiftNotifications()
        }
    }

    /// التحقق من حالة الصلاحيات
    func checkPermissionStatus() async -> NotificationService.PermissionStatus {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                NotificationService.shared.checkPermissionStatus { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    // MARK: - Legacy Fallback

    /// المسار القديم للجدولة (للتوافق الخلفي)
    @MainActor
    private func scheduleLegacy(
        context: ShiftContext,
        overrides: [String: ShiftPhase]
    ) {
        NotificationService.shared.rebuildShiftNotifications(
            context: context,
            manualOverrides: overrides
        )
    }

    // MARK: - Statistics

    /// معلومات إحصائية عن الجدولة
    struct SchedulingStats {
        let isCurrentlyScheduling: Bool
        let lastScheduleTime: Date?
        let totalScheduleCount: Int
    }

    /// الحصول على إحصائيات الجدولة
    func getStats() -> SchedulingStats {
        SchedulingStats(
            isCurrentlyScheduling: isScheduling,
            lastScheduleTime: lastScheduleTime,
            totalScheduleCount: scheduleCount
        )
    }

    // MARK: - Debounced Scheduling

    /// فترة التأخير قبل الجدولة (لمنع الجدولة المتكررة السريعة)
    private let debounceInterval: TimeInterval = 0.5

    /// آخر طلب جدولة
    private var pendingScheduleTask: Task<Void, Never>?

    /// جدولة مع debounce لمنع الجدولة المتكررة
    /// مفيد عند تغييرات متعددة سريعة في الإعدادات
    func scheduleDebounced(
        context: ShiftContext,
        overrides: [String: ShiftPhase]
    ) async {
        // إلغاء أي طلب سابق
        pendingScheduleTask?.cancel()

        // إنشاء طلب جديد مع تأخير
        pendingScheduleTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

                // التحقق من عدم الإلغاء
                guard !Task.isCancelled else { return }

                await scheduleNotifications(context: context, overrides: overrides)
            } catch {
                // Task was cancelled - this is expected
                os_log("Debounced schedule cancelled", log: Self.log, type: .debug)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension NotificationServiceActor {

    /// جدولة سريعة باستخدام UserShift الحالي
    func scheduleFromCurrentContext() async {
        guard let context = await MainActor.run(body: { UserShift.shared.shiftContext }) else {
            os_log("No shift context available - skipping scheduling", log: Self.log, type: .default)
            return
        }

        let overrides = await MainActor.run { UserShift.shared.allManualOverrides }
        await scheduleNotifications(context: context, overrides: overrides)
    }
}
