import Foundation
import os.log

/// MigrationFramework
/// إطار عمل لترحيل بيانات المستخدم بين إصدارات التطبيق.
/// يضمن الانتقال السلس للبيانات مع الحفاظ على نسخ احتياطية.
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Design Principles
/// 1. Never lose user data - always backup before migration
/// 2. Support incremental migrations (v1 → v2 → v3)
/// 3. Provide rollback capability
/// 4. Log all migration activities

// MARK: - Migration Protocol

/// بروتوكول ترحيل البيانات
protocol ShiftDataMigration {
    /// الإصدار المصدر
    var fromVersion: Int { get }
    /// الإصدار الهدف
    var toVersion: Int { get }
    /// معرف فريد للترحيل
    var identifier: String { get }

    /// تنفيذ الترحيل
    /// - Parameter data: البيانات الأصلية
    /// - Returns: البيانات المرحّلة
    func migrate(data: Data) throws -> Data

    /// التراجع عن الترحيل (اختياري)
    /// - Parameter data: البيانات المرحّلة
    /// - Returns: البيانات الأصلية
    func rollback(data: Data) throws -> Data
}

// Default rollback implementation (throws error)
extension ShiftDataMigration {
    func rollback(data: Data) throws -> Data {
        throw MigrationError.rollbackNotSupported(identifier)
    }
}

// MARK: - Migration Result

/// نتيجة عملية الترحيل
struct MigrationResult {
    /// هل نجحت العملية؟
    let success: Bool
    /// الإصدار المصدر
    let fromVersion: Int
    /// الإصدار الهدف
    let toVersion: Int
    /// وقت الترحيل
    let timestamp: Date
    /// مدة التنفيذ بالثواني
    let duration: TimeInterval
    /// الخطأ إن وجد
    let error: Error?
    /// عدد الترحيلات المنفذة
    let migrationsApplied: Int

    var localizedDescription: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        if success {
            return isArabic
                ? "تم ترحيل البيانات من الإصدار \(fromVersion) إلى \(toVersion) بنجاح"
                : "Data migrated from v\(fromVersion) to v\(toVersion) successfully"
        } else {
            return isArabic
                ? "فشل ترحيل البيانات: \(error?.localizedDescription ?? "خطأ غير معروف")"
                : "Migration failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

// MARK: - Migration Error

/// أخطاء الترحيل
enum MigrationError: LocalizedError {
    case noMigrationPath(from: Int, to: Int)
    case migrationFailed(identifier: String, underlying: Error)
    case rollbackNotSupported(String)
    case dataCorruption
    case backupFailed

    var errorDescription: String? {
        switch self {
        case .noMigrationPath(let from, let to):
            return "No migration path from v\(from) to v\(to)"
        case .migrationFailed(let id, let error):
            return "Migration '\(id)' failed: \(error.localizedDescription)"
        case .rollbackNotSupported(let id):
            return "Rollback not supported for migration '\(id)'"
        case .dataCorruption:
            return "Data corruption detected during migration"
        case .backupFailed:
            return "Failed to create backup before migration"
        }
    }
}

// MARK: - Migration Registry

/// سجل الترحيلات المتاحة
final class MigrationRegistry {

    // MARK: - Singleton
    static let shared = MigrationRegistry()
    private init() {
        registerBuiltInMigrations()
    }

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "MigrationRegistry"
    )

    // MARK: - State
    private var migrations: [ShiftDataMigration] = []

    // MARK: - Registration

    /// تسجيل ترحيل جديد
    func register(_ migration: ShiftDataMigration) {
        migrations.append(migration)
        Self.logger.debug("Registered migration: \(migration.identifier)")
    }

    /// إلغاء تسجيل كل الترحيلات (للاختبار)
    func clearAll() {
        migrations.removeAll()
    }

    // MARK: - Query

    /// الحصول على الترحيلات اللازمة للانتقال من إصدار إلى آخر
    func migrationsNeeded(from: Int, to: Int) -> [ShiftDataMigration] {
        guard from < to else { return [] }

        var path: [ShiftDataMigration] = []
        var currentVersion = from

        while currentVersion < to {
            guard let next = migrations.first(where: { $0.fromVersion == currentVersion }) else {
                Self.logger.warning("No migration found from v\(currentVersion)")
                return [] // Incomplete path
            }
            path.append(next)
            currentVersion = next.toVersion
        }

        return path
    }

    /// تنفيذ سلسلة الترحيلات
    func runMigrationChain(data: Data, from: Int, to: Int) -> MigrationResult {
        let startTime = Date()

        let migrations = migrationsNeeded(from: from, to: to)
        guard !migrations.isEmpty else {
            if from == to {
                // No migration needed
                return MigrationResult(
                    success: true,
                    fromVersion: from,
                    toVersion: to,
                    timestamp: startTime,
                    duration: 0,
                    error: nil,
                    migrationsApplied: 0
                )
            }
            return MigrationResult(
                success: false,
                fromVersion: from,
                toVersion: to,
                timestamp: startTime,
                duration: Date().timeIntervalSince(startTime),
                error: MigrationError.noMigrationPath(from: from, to: to),
                migrationsApplied: 0
            )
        }

        Self.logger.info("Starting migration chain: v\(from) → v\(to) (\(migrations.count) steps)")

        var currentData = data
        var appliedCount = 0

        for migration in migrations {
            Self.logger.debug("Applying migration: \(migration.identifier)")
            do {
                currentData = try migration.migrate(data: currentData)
                appliedCount += 1
            } catch {
                Self.logger.error("Migration failed: \(migration.identifier) - \(error.localizedDescription)")
                return MigrationResult(
                    success: false,
                    fromVersion: from,
                    toVersion: migration.toVersion,
                    timestamp: startTime,
                    duration: Date().timeIntervalSince(startTime),
                    error: MigrationError.migrationFailed(identifier: migration.identifier, underlying: error),
                    migrationsApplied: appliedCount
                )
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        Self.logger.info("Migration chain completed in \(String(format: "%.2f", duration))s")

        return MigrationResult(
            success: true,
            fromVersion: from,
            toVersion: to,
            timestamp: startTime,
            duration: duration,
            error: nil,
            migrationsApplied: appliedCount
        )
    }

    // MARK: - Built-in Migrations

    private func registerBuiltInMigrations() {
        // Register v3 → v4 migration (dayKey format change)
        // Additional migrations can be added here in the future
    }
}

// MARK: - Backup Manager

/// إدارة النسخ الاحتياطية قبل الترحيل
final class MigrationBackupManager {

    // MARK: - Singleton
    static let shared = MigrationBackupManager()
    private init() {}

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "MigrationBackup"
    )

    // MARK: - Keys
    private let backupPrefix = "migration_backup_v"
    private let migrationInProgressKey = "migration_in_progress"

    // MARK: - Backup Operations

    /// إنشاء نسخة احتياطية قبل الترحيل
    func createBackup(data: Data, version: Int) -> Bool {
        let key = "\(backupPrefix)\(version)"
        let defaults = UserDefaults.standard

        defaults.set(data, forKey: key)
        defaults.set(true, forKey: migrationInProgressKey)

        Self.logger.info("Created backup for v\(version)")
        return true
    }

    /// استرجاع نسخة احتياطية
    func restoreBackup(version: Int) -> Data? {
        let key = "\(backupPrefix)\(version)"
        return UserDefaults.standard.data(forKey: key)
    }

    /// تأكيد نجاح الترحيل ومسح علم "قيد التنفيذ"
    func confirmMigration() {
        UserDefaults.standard.set(false, forKey: migrationInProgressKey)
        Self.logger.debug("Migration confirmed")
    }

    /// التحقق مما إذا كان هناك ترحيل غير مكتمل
    var isMigrationInProgress: Bool {
        UserDefaults.standard.bool(forKey: migrationInProgressKey)
    }

    /// مسح النسخ الاحتياطية القديمة
    /// يحتفظ فقط بآخر N نسخة ويمسح الباقي
    ///
    /// - Parameter keepCount: Number of recent backups to keep (default: 3)
    func cleanupOldBackups(keepCount: Int = 3) {
        let defaults = UserDefaults.standard

        // Collect all backup keys and their versions
        var backupVersions: [Int] = []

        // Dynamically find all backup keys (no hardcoded limit)
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(backupPrefix),
               let versionString = key.dropFirst(backupPrefix.count).description.components(separatedBy: "_").first,
               let version = Int(versionString) {
                backupVersions.append(version)
            }
        }

        // Sort by version (descending) and remove old ones
        let sortedVersions = backupVersions.sorted(by: >)
        let versionsToRemove = sortedVersions.dropFirst(keepCount)

        for version in versionsToRemove {
            let key = "\(backupPrefix)\(version)"
            defaults.removeObject(forKey: key)
            Self.logger.debug("Cleaned up old backup: v\(version)")
        }

        if !versionsToRemove.isEmpty {
            Self.logger.info("Cleaned up \(versionsToRemove.count) old backup(s), kept \(min(keepCount, sortedVersions.count))")
        }
    }
}
