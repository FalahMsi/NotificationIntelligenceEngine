import Foundation
import Combine
import SwiftUI
import CryptoKit

/// UserShift
/// العقل المدبر لربط إعدادات المستخدم بمحرك النوبات ومعالجة التعديلات اليدوية.
/// تم التحديث: يدعم هيكلة "العقل الجديد" (ساعة الصفر + المرونة) بشكل كامل.
@MainActor
final class UserShift: ObservableObject {

    // MARK: - Singleton
    static let shared = UserShift()

    // MARK: - Keys
    private let contextKey = "user.shift.context.v3"
    private let groupSymbolKey = "user.shift.symbol"
    private let manualOverridesKey = "user.shift.manualOverrides"

    // Phase 4: Backup keys for Government-Grade recovery
    private let backupContextKey = "user.shift.context.backup.v1"
    private let backupChecksumKey = "reference_date_checksum_v1"

    private init() {
        let d = UserDefaults.standard

        if let data = d.data(forKey: contextKey),
           let decoded = try? JSONDecoder().decode(ShiftContext.self, from: data) {
            self.shiftContext = decoded
        }

        self.groupSymbol = d.string(forKey: groupSymbolKey) ?? ""

        if let data = d.data(forKey: manualOverridesKey),
           let decoded = try? JSONDecoder().decode([String: ShiftPhase].self, from: data) {
            self.manualOverrides = decoded
        }
    }

    // MARK: - Source of Truth

    @Published private(set) var shiftContext: ShiftContext?
    @Published private(set) var groupSymbol: String = ""
    @Published private var manualOverrides: [String: ShiftPhase] = [:]

    var allManualOverrides: [String: ShiftPhase] {
        manualOverrides
    }

    // MARK: - Localization Helpers

    private var languageCode: String {
        UserDefaults.standard.string(forKey: "app_language") ?? "ar"
    }

    private var isArabic: Bool {
        languageCode == "ar"
    }

    private var appLocale: Locale {
        Locale(identifier: isArabic ? "ar" : "en")
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = appLocale
        cal.timeZone = .current
        return cal
    }

    // MARK: - Refresh Mechanism 🔄

    /// يجبر SwiftUI على إعادة قراءة القيم وتحديث الواجهات فوراً.
    private func refreshContext() {
        objectWillChange.send() // إجبار التحديث
    }

    // MARK: - Core Actions

    func updateShift(
        systemID: ShiftSystemID,
        startOption: ShiftStartOption,
        date: Date,
        startTime: Date, // هذه هي "ساعة الصفر" (Anchor Time)
        groupSymbol: String? = nil,
        flexibility: ShiftFlexibilityRules
    ) {
        // إشعار الواجهة بأن التغيير قادم
        objectWillChange.send()

        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)

        let newContext = ShiftContext(
            systemID: systemID,
            startPhase: startOption.phase,
            setupIndex: startOption.id,
            shiftStartTime: timeComponents,
            referenceDate: calendar.startOfDay(for: date),
            flexibility: flexibility
        )

        // Phase 5: Only clear manual overrides if the shift system actually changed
        // This prevents data loss when user opens settings without changing the system
        let systemChanged = self.shiftContext?.systemID != systemID

        self.shiftContext = newContext
        if let symbol = groupSymbol {
            self.groupSymbol = symbol
        }

        // تطهير التعديلات اليدوية فقط عند تغيير النظام بالفعل لضمان نظافة الجدول
        if systemChanged {
            self.manualOverrides = [:]
        }

        persist()
        refreshContext()

        // إعادة بناء التنبيهات بناءً على "العقل الجديد"
        // Phase 5: Pass current manualOverrides (may be preserved if system didn't change)
        NotificationService.shared.rebuildShiftNotifications(
            context: newContext,
            manualOverrides: self.manualOverrides
        )
    }

    /// Alias للتوافق مع الواجهات القديمة
    func updateConfig(
        systemID: ShiftSystemID,
        startOption: ShiftStartOption,
        date: Date,
        startTime: Date,
        groupSymbol: String? = nil,
        flexibility: ShiftFlexibilityRules
    ) {
        updateShift(
            systemID: systemID,
            startOption: startOption,
            date: date,
            startTime: startTime,
            groupSymbol: groupSymbol,
            flexibility: flexibility
        )
    }

    func updateGroupSymbol(_ symbol: String) {
        objectWillChange.send()
        self.groupSymbol = symbol
        persist()
        refreshContext()
    }

    func reset() {
        objectWillChange.send()
        shiftContext = nil
        groupSymbol = ""
        manualOverrides = [:]
        persist()
        refreshContext()
        NotificationService.shared.cancelAllShiftNotifications()
    }

    // MARK: - Manual Override API

    func setManualOverride(_ phase: ShiftPhase, for date: Date) {
        guard phase.isVisibleInCalendar else { return }

        objectWillChange.send()

        let key = dayKey(for: date)
        manualOverrides[key] = phase
        persist()
        refreshContext()

        // ✅ P1: Use SystemMessageKind instead of legacy makeOverrideMessage
        let overrideDate = calendar.startOfDay(for: date)
        MessagesStore.shared.add(
            kind: .manualOverrideSet(toPhase: phase.rawValue, overrideDate: overrideDate),
            sourceType: .shift,
            sourceID: overrideSourceID(for: date)
        )

        if let context = shiftContext {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: manualOverrides
            )
        }
    }

    func removeManualOverride(for date: Date) {
        objectWillChange.send()

        let key = dayKey(for: date)
        manualOverrides.removeValue(forKey: key)
        persist()
        refreshContext()

        // ✅ P1: Remove the old "set" message to avoid clutter
        MessagesStore.shared.removeMessages(
            sourceType: .shift,
            sourceID: overrideSourceID(for: date)
        )

        // ✅ P1: Add a "cleared" message for audit trail
        let overrideDate = calendar.startOfDay(for: date)
        MessagesStore.shared.add(
            kind: .manualOverrideCleared(overrideDate: overrideDate),
            sourceType: .shift,
            sourceID: nil  // No stable ID needed — this is a one-time event
        )

        if let context = shiftContext {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: manualOverrides
            )
        }
    }

    func manualOverride(for date: Date) -> ShiftPhase? {
        let key = dayKey(for: date)
        guard let phase = manualOverrides[key], phase.isVisibleInCalendar else {
            return nil
        }
        return phase
    }

    // MARK: - Stable UUID for day-based messages ✅

    private func overrideSourceID(for date: Date) -> UUID {
        stableUUID(for: "shift_override_" + dayKey(for: date))
    }

    private func stableUUID(for input: String) -> UUID {
        let digest = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(digest.prefix(16))

        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let uuid = bytes.withUnsafeBytes { raw -> UUID in
            let p = raw.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return UUID(uuid: (
                p[0], p[1], p[2], p[3],
                p[4], p[5],
                p[6], p[7],
                p[8], p[9],
                p[10], p[11], p[12], p[13], p[14], p[15]
            ))
        }
        return uuid
    }

    // MARK: - Persistence

    private func persist() {
        let d = UserDefaults.standard

        if let context = shiftContext,
           let data = try? JSONEncoder().encode(context) {
            d.set(data, forKey: contextKey)

            // Phase 4: Save backup and checksum for Government-Grade recovery
            d.set(data, forKey: backupContextKey)
            if let setupIndex = context.setupIndex {
                let checksum = ReferenceDateValidator.shared.generateChecksum(
                    date: context.referenceDate,
                    setupIndex: setupIndex
                )
                ReferenceDateValidator.shared.saveChecksum(checksum)
                ReferenceDateValidator.shared.saveBackup(
                    referenceDate: context.referenceDate,
                    setupIndex: setupIndex
                )
            }
        } else {
            d.removeObject(forKey: contextKey)
        }

        d.set(groupSymbol, forKey: groupSymbolKey)

        if let data = try? JSONEncoder().encode(manualOverrides) {
            d.set(data, forKey: manualOverridesKey)
        } else {
            d.removeObject(forKey: manualOverridesKey)
        }
    }

    // MARK: - Phase 4: Validation & Recovery (Government-Grade Hardening)

    /// Validate stored reference date and return validation result
    func validateReferenceDate() -> ReferenceDateValidator.ValidationResult {
        let validator = ReferenceDateValidator.shared
        let backup = validator.loadBackup()
        let storedChecksum = validator.loadChecksum()

        return validator.validateWithBackup(
            primaryDate: shiftContext?.referenceDate,
            primaryIndex: shiftContext?.setupIndex,
            primaryChecksum: storedChecksum,
            backupDate: backup.date,
            backupIndex: backup.index
        )
    }

    /// Attempt to recover from backup if primary data is corrupted
    /// Returns true if recovery was successful
    func attemptBackupRecovery() -> Bool {
        let validator = ReferenceDateValidator.shared
        let backup = validator.loadBackup()

        guard let backupDate = backup.date, let backupIndex = backup.index else {
            return false
        }

        // Validate backup before using it
        let backupResult = validator.validate(
            referenceDate: backupDate,
            setupIndex: backupIndex,
            storedChecksum: nil // Backup doesn't have its own checksum
        )

        guard backupResult.isValid else {
            return false
        }

        // Restore from backup
        guard let currentContext = shiftContext else {
            return false
        }

        // Create new context with recovered reference date
        let recoveredContext = ShiftContext(
            systemID: currentContext.systemID,
            startPhase: currentContext.startPhase,
            setupIndex: backupIndex,
            shiftStartTime: currentContext.shiftStartTime,
            referenceDate: backupDate,
            flexibility: currentContext.flexibility,
            workDurationHours: currentContext.workDurationHours,
            timeZone: currentContext.timeZone
        )

        objectWillChange.send()
        self.shiftContext = recoveredContext
        persist()
        refreshContext()

        return true
    }

    /// Update reference date after wizard verification
    func updateReferenceDateFromWizard(referenceDate: Date, setupIndex: Int) {
        guard let currentContext = shiftContext else { return }

        objectWillChange.send()

        let newContext = ShiftContext(
            systemID: currentContext.systemID,
            startPhase: currentContext.startPhase,
            setupIndex: setupIndex,
            shiftStartTime: currentContext.shiftStartTime,
            referenceDate: calendar.startOfDay(for: referenceDate),
            flexibility: currentContext.flexibility,
            workDurationHours: currentContext.workDurationHours,
            timeZone: currentContext.timeZone
        )

        self.shiftContext = newContext
        persist()
        refreshContext()

        // Rebuild notifications with corrected reference date
        NotificationService.shared.rebuildShiftNotifications(
            context: newContext,
            manualOverrides: manualOverrides
        )
    }

    /// Get available phases for the current shift system (for wizard)
    func availablePhasesForWizard() -> [ShiftPhase] {
        guard let context = shiftContext else { return [] }
        let system = ShiftEngine.shared.system(for: context.systemID)
        return system.phases
    }

    // MARK: - Helpers

    /// Generates a canonical day key using DayKeyGenerator.
    /// Format: YYYY-MM-DD (zero-padded).
    ///
    /// - Important: Uses DayKeyGenerator as single source of truth to ensure
    ///              consistency with UpcomingShiftResolver's manual override lookup.
    private func dayKey(for date: Date) -> String {
        DayKeyGenerator.key(for: date, calendar: calendar)
    }
}
