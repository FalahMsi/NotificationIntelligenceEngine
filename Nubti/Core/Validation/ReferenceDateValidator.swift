import Foundation
import CryptoKit
import os.log

/// ReferenceDateValidator
/// مدقق سلامة تاريخ المرجع - يتحقق من صحة البيانات المخزنة ويكتشف التلف.
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Validation Rules
/// - Reference date must not be nil
/// - Reference date must not be more than 1 day in the future
/// - Reference date must not be older than 2 years
/// - Checksum must match (if stored)
///
/// ## Usage
/// ```swift
/// let result = ReferenceDateValidator.shared.validate(
///     referenceDate: storedDate,
///     setupIndex: storedIndex,
///     storedChecksum: storedChecksum
/// )
/// if result != .valid {
///     // Trigger recovery wizard
/// }
/// ```
struct ReferenceDateValidator {

    // MARK: - Singleton
    static let shared = ReferenceDateValidator()
    private init() {}

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "ReferenceDateValidator"
    )

    // MARK: - Constants

    /// Maximum allowed days in the future (1 day tolerance for timezone edge cases)
    private let maxFutureDays: Int = 1

    /// Maximum allowed age in years (2 years reasonable for shift history)
    private let maxAgeYears: Int = 2

    /// Salt for checksum generation (app-specific)
    private let checksumSalt = "nubti_ref_date_v1_integrity"

    /// UserDefaults key for storing checksum
    static let checksumKey = "reference_date_checksum_v1"

    /// UserDefaults key for backup reference date
    static let backupReferenceDateKey = "reference_date_backup_v1"

    /// UserDefaults key for backup setup index
    static let backupSetupIndexKey = "setup_index_backup_v1"

    // MARK: - Validation Result

    /// نتيجة التحقق من صحة تاريخ المرجع
    enum ValidationResult: Equatable {
        case valid
        case missing
        case futureDate(daysAhead: Int)
        case tooOld(yearsOld: Int)
        case checksumMismatch
        case setupIndexMissing
        case backupMismatch

        var isValid: Bool {
            self == .valid
        }

        var localizedDescription: String {
            let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
            switch self {
            case .valid:
                return isArabic ? "صالح" : "Valid"
            case .missing:
                return isArabic ? "تاريخ المرجع مفقود" : "Reference date missing"
            case .futureDate(let days):
                return isArabic ? "تاريخ المرجع في المستقبل بـ \(days) أيام" : "Reference date is \(days) days in the future"
            case .tooOld(let years):
                return isArabic ? "تاريخ المرجع قديم جداً (\(years) سنوات)" : "Reference date is too old (\(years) years)"
            case .checksumMismatch:
                return isArabic ? "بصمة البيانات غير متطابقة" : "Data checksum mismatch"
            case .setupIndexMissing:
                return isArabic ? "فهرس الإعداد مفقود" : "Setup index missing"
            case .backupMismatch:
                return isArabic ? "عدم تطابق بين البيانات الأساسية والاحتياطية" : "Primary and backup data mismatch"
            }
        }

        var requiresRecovery: Bool {
            switch self {
            case .valid:
                return false
            case .missing, .checksumMismatch, .setupIndexMissing, .backupMismatch:
                return true
            case .futureDate, .tooOld:
                return true
            }
        }
    }

    // MARK: - Core Validation

    /// التحقق الشامل من صحة تاريخ المرجع
    /// - Parameters:
    ///   - referenceDate: تاريخ المرجع المخزن
    ///   - setupIndex: فهرس الإعداد المخزن
    ///   - storedChecksum: بصمة البيانات المخزنة (اختياري للتوافق مع البيانات القديمة)
    /// - Returns: نتيجة التحقق
    func validate(
        referenceDate: Date?,
        setupIndex: Int?,
        storedChecksum: String?
    ) -> ValidationResult {

        Self.logger.info("Starting reference date validation...")

        // 1. التحقق من وجود التاريخ
        guard let date = referenceDate else {
            Self.logger.warning("Validation failed: Reference date is nil")
            return .missing
        }

        // 2. التحقق من وجود setupIndex
        guard let index = setupIndex else {
            Self.logger.warning("Validation failed: Setup index is nil")
            return .setupIndexMissing
        }

        let calendar = Calendar.current
        let now = Date()

        // 3. التحقق من أن التاريخ ليس في المستقبل البعيد
        if let daysDifference = calendar.dateComponents([.day], from: now, to: date).day,
           daysDifference > maxFutureDays {
            Self.logger.warning("Validation failed: Date is \(daysDifference) days in the future")
            return .futureDate(daysAhead: daysDifference)
        }

        // 4. التحقق من أن التاريخ ليس قديماً جداً
        if let yearsDifference = calendar.dateComponents([.year], from: date, to: now).year,
           yearsDifference > maxAgeYears {
            Self.logger.warning("Validation failed: Date is \(yearsDifference) years old")
            return .tooOld(yearsOld: yearsDifference)
        }

        // 5. التحقق من بصمة البيانات (إذا كانت مخزنة)
        if let stored = storedChecksum {
            let computed = generateChecksum(date: date, setupIndex: index)
            if stored != computed {
                Self.logger.warning("Validation failed: Checksum mismatch")
                Self.logger.debug("Stored: \(stored), Computed: \(computed)")
                return .checksumMismatch
            }
        } else {
            // بيانات قديمة بدون بصمة - نقبلها ونُنشئ بصمة جديدة
            Self.logger.info("No checksum stored (legacy data) - will generate on next save")
        }

        Self.logger.info("Validation passed successfully")
        return .valid
    }

    /// التحقق السريع مع المقارنة بالنسخة الاحتياطية
    func validateWithBackup(
        primaryDate: Date?,
        primaryIndex: Int?,
        primaryChecksum: String?,
        backupDate: Date?,
        backupIndex: Int?
    ) -> ValidationResult {

        // أولاً: تحقق من البيانات الأساسية
        let primaryResult = validate(
            referenceDate: primaryDate,
            setupIndex: primaryIndex,
            storedChecksum: primaryChecksum
        )

        // إذا كانت البيانات الأساسية صالحة، تحقق من تطابقها مع النسخة الاحتياطية
        if primaryResult.isValid {
            // إذا لا توجد نسخة احتياطية، البيانات الأساسية كافية
            guard let backup = backupDate, let backupIdx = backupIndex else {
                return .valid
            }

            // تحقق من تطابق البيانات
            let calendar = Calendar.current
            let datesMatch = calendar.isDate(primaryDate!, inSameDayAs: backup)
            let indicesMatch = primaryIndex == backupIdx

            if !datesMatch || !indicesMatch {
                Self.logger.warning("Primary and backup data mismatch detected")
                return .backupMismatch
            }
        }

        return primaryResult
    }

    // MARK: - Checksum Generation

    /// إنشاء بصمة فريدة للبيانات للتحقق من سلامتها
    /// - Parameters:
    ///   - date: تاريخ المرجع
    ///   - setupIndex: فهرس الإعداد
    /// - Returns: بصمة SHA256 مختصرة
    func generateChecksum(date: Date, setupIndex: Int) -> String {
        // إنشاء سلسلة نصية فريدة
        let timestamp = Int(date.timeIntervalSince1970)
        let input = "\(timestamp)_\(setupIndex)_\(checksumSalt)"

        // حساب SHA256
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)

        // تحويل إلى سلسلة hex مختصرة (أول 16 حرف)
        let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(16))
    }

    /// التحقق من صحة البصمة
    func verifyChecksum(date: Date, setupIndex: Int, storedChecksum: String) -> Bool {
        let computed = generateChecksum(date: date, setupIndex: setupIndex)
        return computed == storedChecksum
    }

    // MARK: - Backup Management

    /// حفظ نسخة احتياطية من البيانات
    func saveBackup(referenceDate: Date, setupIndex: Int) {
        let defaults = UserDefaults.standard
        defaults.set(referenceDate, forKey: Self.backupReferenceDateKey)
        defaults.set(setupIndex, forKey: Self.backupSetupIndexKey)
        Self.logger.info("Backup saved: date=\(referenceDate), index=\(setupIndex)")
    }

    /// تحميل النسخة الاحتياطية
    func loadBackup() -> (date: Date?, index: Int?) {
        let defaults = UserDefaults.standard
        let date = defaults.object(forKey: Self.backupReferenceDateKey) as? Date
        let index = defaults.object(forKey: Self.backupSetupIndexKey) != nil
            ? defaults.integer(forKey: Self.backupSetupIndexKey)
            : nil
        return (date, index)
    }

    /// حفظ البصمة
    func saveChecksum(_ checksum: String) {
        UserDefaults.standard.set(checksum, forKey: Self.checksumKey)
        Self.logger.info("Checksum saved")
    }

    /// تحميل البصمة
    func loadChecksum() -> String? {
        UserDefaults.standard.string(forKey: Self.checksumKey)
    }

    // MARK: - Recovery Helpers

    /// حساب تاريخ المرجع الصحيح من نوبة اليوم
    /// - Parameters:
    ///   - todayPhase: النوبة التي يعمل بها المستخدم اليوم
    ///   - systemPhases: دورة النظام (مثل: [morning, evening, night, off, off])
    /// - Returns: تاريخ المرجع المحسوب وفهرس الإعداد
    func calculateReferenceFromToday(
        todayPhase: ShiftPhase,
        systemPhases: [ShiftPhase]
    ) -> (referenceDate: Date, setupIndex: Int)? {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // البحث عن موقع النوبة في الدورة
        guard let phaseIndex = systemPhases.firstIndex(of: todayPhase) else {
            Self.logger.error("Phase \(todayPhase.rawValue) not found in system phases")
            return nil
        }

        // تاريخ المرجع = اليوم (لأن اليوم هو يوم النوبة المحددة)
        // فهرس الإعداد = موقع النوبة في الدورة
        Self.logger.info("Calculated reference: today=\(today), index=\(phaseIndex)")
        return (today, phaseIndex)
    }

    /// إعادة تعيين البيانات بالكامل
    func clearAllValidationData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.checksumKey)
        defaults.removeObject(forKey: Self.backupReferenceDateKey)
        defaults.removeObject(forKey: Self.backupSetupIndexKey)
        Self.logger.info("All validation data cleared")
    }
}
