import Foundation
import os.log

/// FeatureFlags
/// مركز التحكم في الميزات التجريبية والإقليمية.
/// يسمح بتفعيل/تعطيل الميزات بشكل آمن مع القدرة على التراجع.
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Design Principles
/// 1. Default to OFF for new features
/// 2. Log all flag changes
/// 3. Store in UserDefaults for persistence
/// 4. Support regional defaults (e.g., DST off for Kuwait)
struct FeatureFlags {

    // MARK: - Keys
    private static let storageKey = "feature_flags_v1"

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "FeatureFlags"
    )

    // MARK: - DST (Daylight Saving Time)

    /// هل يتم تطبيق معالجة التوقيت الصيفي؟
    /// - الافتراضي: false (الكويت ومعظم الخليج لا يستخدمون DST)
    /// - يجب تفعيله فقط للمناطق التي تستخدم DST (مصر، أوروبا، أمريكا)
    static var DST_AWARE_MODE: Bool {
        get {
            load()?.dstAwareMode ?? defaultFlags.dstAwareMode
        }
        set {
            var flags = load() ?? defaultFlags
            flags.dstAwareMode = newValue
            save(flags)
            logger.info("DST_AWARE_MODE changed to: \(newValue)")
        }
    }

    /// هل يتم عرض تنبيهات DST للمستخدم؟
    static var DST_SHOW_ALERTS: Bool {
        get {
            load()?.dstShowAlerts ?? defaultFlags.dstShowAlerts
        }
        set {
            var flags = load() ?? defaultFlags
            flags.dstShowAlerts = newValue
            save(flags)
            logger.info("DST_SHOW_ALERTS changed to: \(newValue)")
        }
    }

    // MARK: - Concurrency

    /// هل يتم استخدام Actor للإشعارات؟ (للاختبار والتراجع)
    static var USE_NOTIFICATION_ACTOR: Bool {
        get {
            load()?.useNotificationActor ?? defaultFlags.useNotificationActor
        }
        set {
            var flags = load() ?? defaultFlags
            flags.useNotificationActor = newValue
            save(flags)
            logger.info("USE_NOTIFICATION_ACTOR changed to: \(newValue)")
        }
    }

    // MARK: - Validation

    /// هل يتم التحقق من تاريخ المرجع عند كل تشغيل؟
    static var REFERENCE_DATE_VALIDATION: Bool {
        get {
            load()?.referenceDateValidation ?? defaultFlags.referenceDateValidation
        }
        set {
            var flags = load() ?? defaultFlags
            flags.referenceDateValidation = newValue
            save(flags)
            logger.info("REFERENCE_DATE_VALIDATION changed to: \(newValue)")
        }
    }

    // MARK: - Timezone

    /// هل يتم إعادة بناء التنبيهات عند تغيير المنطقة الزمنية؟
    static var TIMEZONE_AUTO_REBUILD: Bool {
        get {
            load()?.timezoneAutoRebuild ?? defaultFlags.timezoneAutoRebuild
        }
        set {
            var flags = load() ?? defaultFlags
            flags.timezoneAutoRebuild = newValue
            save(flags)
            logger.info("TIMEZONE_AUTO_REBUILD changed to: \(newValue)")
        }
    }

    // MARK: - Defaults

    /// القيم الافتراضية (متحفظة للكويت)
    private static let defaultFlags = StoredFlags(
        dstAwareMode: false,        // الكويت لا تستخدم DST
        dstShowAlerts: false,       // لا تنبيهات DST
        useNotificationActor: true, // استخدام Actor للإشعارات
        referenceDateValidation: true, // التحقق من تاريخ المرجع
        timezoneAutoRebuild: true   // إعادة البناء عند تغيير المنطقة الزمنية
    )

    // MARK: - Storage

    private struct StoredFlags: Codable {
        var dstAwareMode: Bool
        var dstShowAlerts: Bool
        var useNotificationActor: Bool
        var referenceDateValidation: Bool
        var timezoneAutoRebuild: Bool
    }

    private static func load() -> StoredFlags? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(StoredFlags.self, from: data)
    }

    private static func save(_ flags: StoredFlags) {
        guard let data = try? JSONEncoder().encode(flags) else {
            logger.error("Failed to encode feature flags")
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Debug

    /// عرض جميع القيم الحالية (للتشخيص)
    static func debugDump() -> String {
        """
        Feature Flags:
        - DST_AWARE_MODE: \(DST_AWARE_MODE)
        - DST_SHOW_ALERTS: \(DST_SHOW_ALERTS)
        - USE_NOTIFICATION_ACTOR: \(USE_NOTIFICATION_ACTOR)
        - REFERENCE_DATE_VALIDATION: \(REFERENCE_DATE_VALIDATION)
        - TIMEZONE_AUTO_REBUILD: \(TIMEZONE_AUTO_REBUILD)
        """
    }

    /// إعادة تعيين جميع القيم للافتراضي
    static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        logger.info("All feature flags reset to defaults")
    }
}
