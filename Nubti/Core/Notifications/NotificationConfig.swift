import Foundation
import os.log

/// NotificationConfig (V3)
/// نموذج الإعدادات المتقدمة للإشعارات - المصدر الوحيد للحقيقة
/// يوفر مرونة للمستخدمين المتقدمين مع الحفاظ على البساطة للمستخدمين العاديين
///
/// ## Design Principles
/// - Single Source of Truth: All notification settings live here
/// - Opt-in complexity: defaults work for 90% of users
/// - Backward compatible: V1/V2 migration handled transparently
/// - Codable for persistence
/// - Thread-safe via UserDefaults
///
/// ## Migration History
/// - V1: UserDefaults keys (enable_punch_in, etc.) - LEGACY
/// - V2: NotificationAdvancedConfig struct introduced
/// - V3: Unified config, legacy keys read-only for migration

// MARK: - Entry Notification Config

struct EntryNotificationConfig: Codable, Equatable {
    /// تفعيل تنبيه الدخول
    var enabled: Bool = true

    /// الوقت المسبق الرئيسي (بالدقائق قبل بداية الدوام)
    /// الافتراضي: 30 دقيقة
    var primaryOffset: Int = 30

    /// تفعيل تنبيه ثانوي (اختياري)
    var secondaryEnabled: Bool = false

    /// الوقت المسبق الثانوي (بالدقائق)
    /// الافتراضي: 0 (في الوقت المحدد)
    var secondaryOffset: Int = 0

    /// تنبيه في الوقت المحدد بالضبط
    var atExactTime: Bool = false
}

// MARK: - Presence Notification Config

struct PresenceNotificationConfig: Codable, Equatable {
    /// تفعيل تنبيه التواجد
    var enabled: Bool = false

    /// الوقت بعد بداية الدوام (بالدقائق)
    /// الافتراضي: 120 دقيقة (ساعتين)
    var primaryOffset: Int = 120

    /// تفعيل تنبيه متابعة (اختياري)
    var secondaryEnabled: Bool = false

    /// التأخير بعد التنبيه الأول (بالدقائق)
    /// الافتراضي: 15 دقيقة
    var secondaryDelay: Int = 15
}

// MARK: - Exit Notification Config

struct ExitNotificationConfig: Codable, Equatable {
    /// تفعيل تنبيه الخروج
    var enabled: Bool = false

    /// تنبيه مسبق قبل نهاية الدوام (بالدقائق)
    /// الافتراضي: 0 (لا تنبيه مسبق)
    var advanceWarning: Int = 0

    /// تنبيه في الوقت المحدد بالضبط
    /// الافتراضي: true
    var atExactTime: Bool = true
}

// MARK: - Global Notification Config

struct GlobalNotificationConfig: Codable, Equatable {
    /// الحد الأقصى للإشعارات يومياً
    /// الافتراضي: 6
    var maxNotificationsPerDay: Int = 6

    /// تفعيل ساعات الهدوء
    var quietHoursEnabled: Bool = false

    /// بداية ساعات الهدوء (ساعة:دقيقة)
    var quietHoursStartHour: Int = 22
    var quietHoursStartMinute: Int = 0

    /// نهاية ساعات الهدوء (ساعة:دقيقة)
    var quietHoursEndHour: Int = 7
    var quietHoursEndMinute: Int = 0

    /// تفعيل تنبيه ما قبل اليوم
    var preDayReminderEnabled: Bool = false

    /// عدد الساعات قبل بداية الدوام للتذكير
    /// الافتراضي: 12 ساعة
    /// النطاق المسموح: 1-24 ساعة
    var preDayReminderHours: Int = 12
}

// MARK: - Main Config Model

struct NotificationAdvancedConfig: Codable, Equatable {
    /// إصدار الإعدادات (للترحيل)
    /// V3 = unified config, single source of truth
    var version: Int = 3

    /// إعدادات تنبيه الدخول
    var entry: EntryNotificationConfig = EntryNotificationConfig()

    /// إعدادات تنبيه التواجد
    var presence: PresenceNotificationConfig = PresenceNotificationConfig()

    /// إعدادات تنبيه الخروج
    var exit: ExitNotificationConfig = ExitNotificationConfig()

    /// الإعدادات العامة
    var global: GlobalNotificationConfig = GlobalNotificationConfig()

    // MARK: - Defaults

    /// الإعدادات الافتراضية
    static let `default` = NotificationAdvancedConfig()

    /// إعدادات الـ Essential Preset
    static var essentialPreset: NotificationAdvancedConfig {
        var config = NotificationAdvancedConfig()
        config.entry.enabled = true
        config.entry.primaryOffset = 30
        config.presence.enabled = false
        config.exit.enabled = false
        return config
    }

    /// إعدادات الـ All Preset
    static var allPreset: NotificationAdvancedConfig {
        var config = NotificationAdvancedConfig()
        config.entry.enabled = true
        config.entry.primaryOffset = 30
        config.presence.enabled = true
        config.presence.primaryOffset = 120
        config.exit.enabled = true
        config.exit.atExactTime = true
        return config
    }

    /// إعدادات الـ Off Preset
    static var offPreset: NotificationAdvancedConfig {
        var config = NotificationAdvancedConfig()
        config.entry.enabled = false
        config.presence.enabled = false
        config.exit.enabled = false
        return config
    }
}

// MARK: - Persistence Manager

final class NotificationConfigStore {
    static let shared = NotificationConfigStore()
    private init() {}

    private let configKey = "notification_advanced_config_v3"
    private let legacyConfigKey = "notification_advanced_config_v2"
    private let migrationFlagKey = "notification_v1_migrated"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app", category: "NotificationConfig")

    // MARK: - Legacy UserDefaults Keys (V1) - READ ONLY FOR MIGRATION
    private enum LegacyKeys {
        static let enablePunchIn = "enable_punch_in"
        static let enablePresencePunch = "enable_presence_punch"
        static let enablePunchOut = "enable_punch_out"
        static let punchInOffset = "punch_in_offset"
        static let presenceOffset = "presence_offset"
    }

    /// حفظ الإعدادات
    func save(_ config: NotificationAdvancedConfig) {
        var configToSave = config
        configToSave.version = 3
        if let data = try? JSONEncoder().encode(configToSave) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    /// تحميل الإعدادات مع الترحيل التلقائي من V1/V2
    func load() -> NotificationAdvancedConfig {
        // 1. Try loading V3 config first
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(NotificationAdvancedConfig.self, from: data),
           config.version >= 3 {
            return config
        }

        // 2. Try migrating from V2
        if let data = UserDefaults.standard.data(forKey: legacyConfigKey),
           let config = try? JSONDecoder().decode(NotificationAdvancedConfig.self, from: data) {
            var migratedConfig = config
            migratedConfig.version = 3
            save(migratedConfig)
            return migratedConfig
        }

        // 3. Migrate from V1 legacy UserDefaults keys
        return migrateFromV1()
    }

    /// ترحيل من V1 (مفاتيح UserDefaults القديمة)
    private func migrateFromV1() -> NotificationAdvancedConfig {
        let defaults = UserDefaults.standard

        // Check if already migrated
        if defaults.bool(forKey: migrationFlagKey) {
            return .default
        }

        var config = NotificationAdvancedConfig()
        config.version = 3

        // Read legacy enable flags
        // Note: UserDefaults.bool returns false if key doesn't exist
        let hasLegacyKeys = defaults.object(forKey: LegacyKeys.enablePunchIn) != nil

        if hasLegacyKeys {
            config.entry.enabled = defaults.bool(forKey: LegacyKeys.enablePunchIn)
            config.presence.enabled = defaults.bool(forKey: LegacyKeys.enablePresencePunch)
            config.exit.enabled = defaults.bool(forKey: LegacyKeys.enablePunchOut)

            // Read legacy offsets
            let punchInOffset = defaults.integer(forKey: LegacyKeys.punchInOffset)
            if punchInOffset > 0 {
                config.entry.primaryOffset = punchInOffset
            }

            let presenceOffset = defaults.integer(forKey: LegacyKeys.presenceOffset)
            if presenceOffset > 0 {
                config.presence.primaryOffset = presenceOffset
            }

            logger.info("🔄 [NotificationConfig] Migrated from V1 legacy keys")
        }

        // Save migrated config
        save(config)

        // Mark migration complete (don't delete legacy keys for safety)
        defaults.set(true, forKey: migrationFlagKey)

        return config
    }

    /// إعادة تعيين للإعدادات الافتراضية
    func reset() {
        save(.default)
    }

    /// تطبيق Preset على الإعدادات
    func applyPreset(_ preset: NotificationPreset) {
        switch preset {
        case .off:
            save(.offPreset)
        case .essential:
            save(.essentialPreset)
        case .all:
            save(.allPreset)
        }
    }
}
