import Foundation
import os.log

/// DayKeyMigration
/// ترحيل مفاتيح الأيام من التنسيق القديم إلى التنسيق الجديد المبطن بالأصفار.
/// القديم: "2026-1-5" → الجديد: "2026-01-05"
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Why Zero-Padding?
/// 1. Consistent sorting in dictionaries
/// 2. Proper date comparison
/// 3. Standard ISO 8601 date format
/// 4. Avoids edge cases in string matching
final class DayKeyMigration {

    // MARK: - Singleton
    static let shared = DayKeyMigration()
    private init() {}

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "DayKeyMigration"
    )

    // MARK: - Keys
    private let migrationCompleteKey = "daykey_migration_complete_v1"

    // MARK: - Migration State

    /// هل تم تنفيذ الترحيل؟
    var isMigrationComplete: Bool {
        UserDefaults.standard.bool(forKey: migrationCompleteKey)
    }

    // MARK: - Core Logic

    /// تنفيذ الترحيل إذا لزم الأمر
    @discardableResult
    func migrateIfNeeded() -> MigrationStats {
        guard !isMigrationComplete else {
            Self.logger.debug("DayKey migration already complete, skipping")
            return MigrationStats(legacyKeysFound: 0, keysMigrated: 0, skipped: true)
        }

        Self.logger.info("Starting dayKey migration...")
        let stats = performMigration()

        // Mark as complete
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)

        Self.logger.info("DayKey migration complete: \(stats.keysMigrated) keys migrated")
        return stats
    }

    /// تنفيذ الترحيل الفعلي
    private func performMigration() -> MigrationStats {
        let defaults = UserDefaults.standard
        let manualOverridesKey = "user.shift.manualOverrides"

        guard let data = defaults.data(forKey: manualOverridesKey),
              let overrides = try? JSONDecoder().decode([String: ShiftPhase].self, from: data) else {
            Self.logger.debug("No manual overrides to migrate")
            return MigrationStats(legacyKeysFound: 0, keysMigrated: 0, skipped: false)
        }

        var migrated: [String: ShiftPhase] = [:]
        var legacyCount = 0
        var migratedCount = 0

        for (key, phase) in overrides {
            if isLegacyFormat(key) {
                legacyCount += 1
                if let newKey = convertToNewFormat(key) {
                    migrated[newKey] = phase
                    migratedCount += 1
                    Self.logger.debug("Migrated key: \(key) → \(newKey)")
                } else {
                    // Keep original if conversion fails
                    migrated[key] = phase
                    Self.logger.warning("Failed to convert key: \(key), keeping original")
                }
            } else {
                // Already in new format
                migrated[key] = phase
            }
        }

        // Save migrated data
        if migratedCount > 0 {
            if let newData = try? JSONEncoder().encode(migrated) {
                defaults.set(newData, forKey: manualOverridesKey)
                Self.logger.info("Saved \(migrated.count) migrated overrides")
            }
        }

        return MigrationStats(legacyKeysFound: legacyCount, keysMigrated: migratedCount, skipped: false)
    }

    // MARK: - Format Detection

    /// التحقق مما إذا كان المفتاح بالتنسيق القديم
    /// القديم: "2026-1-5" (لا يوجد أصفار بادئة)
    /// الجديد: "2026-01-05" (مبطن بالأصفار)
    func isLegacyFormat(_ key: String) -> Bool {
        let components = key.split(separator: "-")
        guard components.count == 3 else { return false }

        // Check if month or day is single digit (legacy format)
        let month = String(components[1])
        let day = String(components[2])

        return month.count == 1 || day.count == 1
    }

    /// تحويل المفتاح من التنسيق القديم إلى الجديد
    /// - Note: Uses DayKeyGenerator.canonicalize as single source of truth
    func convertToNewFormat(_ key: String) -> String? {
        // Validate that the key can be parsed
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              Int(parts[0]) != nil,
              Int(parts[1]) != nil,
              Int(parts[2]) != nil else {
            return nil
        }
        return DayKeyGenerator.canonicalize(key)
    }

    /// تحويل المفتاح من التنسيق الجديد إلى القديم (للبحث المزدوج)
    func convertToLegacyFormat(_ key: String) -> String? {
        let components = key.split(separator: "-")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return nil
        }

        return "\(year)-\(month)-\(day)"
    }

    // MARK: - Stats

    /// إحصائيات الترحيل
    struct MigrationStats {
        let legacyKeysFound: Int
        let keysMigrated: Int
        let skipped: Bool

        var description: String {
            if skipped {
                return "Migration skipped (already complete)"
            }
            return "Found \(legacyKeysFound) legacy keys, migrated \(keysMigrated)"
        }
    }

    // MARK: - Reset (Testing)

    /// إعادة تعيين حالة الترحيل (للاختبار)
    func resetMigrationState() {
        UserDefaults.standard.removeObject(forKey: migrationCompleteKey)
        Self.logger.warning("Migration state reset")
    }
}

// MARK: - UserShift Extension for Dual Lookup

extension UserShift {
    /// البحث المزدوج للتعديلات اليدوية (يدعم كلا التنسيقين)
    /// - Parameter date: التاريخ المطلوب
    /// - Returns: المرحلة إن وجدت
    func manualOverrideWithDualLookup(for date: Date) -> ShiftPhase? {
        // Try canonical format first (using DayKeyGenerator)
        let canonicalKey = DayKeyGenerator.key(for: date)
        if let phase = allManualOverrides[canonicalKey], phase.isVisibleInCalendar {
            return phase
        }

        // Fallback to legacy format for backward compatibility
        let legacyKey = DayKeyGenerator.legacyKey(for: date)
        if let phase = allManualOverrides[legacyKey], phase.isVisibleInCalendar {
            return phase
        }

        return nil
    }

    /// مفتاح اليوم بالتنسيق الجديد (مبطن بالأصفار)
    /// - Note: Uses DayKeyGenerator as single source of truth
    func dayKeyNew(for date: Date) -> String {
        DayKeyGenerator.key(for: date)
    }

    /// مفتاح اليوم بالتنسيق القديم (بدون أصفار بادئة)
    /// - Note: Uses DayKeyGenerator as single source of truth
    func dayKeyLegacy(for date: Date) -> String {
        DayKeyGenerator.legacyKey(for: date)
    }
}
