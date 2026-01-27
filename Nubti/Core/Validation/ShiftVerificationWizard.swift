import Foundation
import SwiftUI
import Combine
import os.log

/// ShiftVerificationWizard
/// معالج استرداد جدول النوبات - يظهر عند اكتشاف تلف في البيانات.
/// يرشد المستخدم لتأكيد نوبته الحالية لإعادة حساب تاريخ المرجع.
///
/// ## Flow
/// 1. App detects corruption via ReferenceDateValidator
/// 2. Wizard is presented modally
/// 3. User selects today's shift phase
/// 4. System recalculates referenceDate and setupIndex
/// 5. Data is saved with new checksum
/// 6. Activity Log records the recovery
///
/// ## Usage
/// ```swift
/// @StateObject var wizard = ShiftVerificationWizard.shared
///
/// .sheet(isPresented: $wizard.isPresented) {
///     ShiftVerificationView()
/// }
/// ```
@MainActor
final class ShiftVerificationWizard: ObservableObject {

    // MARK: - Singleton
    static let shared = ShiftVerificationWizard()
    private init() {}

    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app",
        category: "ShiftVerificationWizard"
    )

    // MARK: - Published State

    /// هل المعالج معروض حالياً؟
    @Published var isPresented: Bool = false

    /// النوبة المختارة من المستخدم
    @Published var selectedPhase: ShiftPhase?

    /// حالة المعالجة
    @Published var state: WizardState = .idle

    /// سبب ظهور المعالج
    @Published var validationResult: ReferenceDateValidator.ValidationResult?

    /// النوبات المتاحة للاختيار (تعتمد على نظام الشفت الحالي)
    @Published var availablePhases: [ShiftPhase] = []

    /// رسالة الخطأ (إن وجدت)
    @Published var errorMessage: String?

    // MARK: - State Machine

    enum WizardState: Equatable {
        case idle
        case presenting
        case processingSelection
        case completed
        case failed(String)
        case dismissed
    }

    // MARK: - UserDefaults Keys

    private let needsVerificationKey = "shift_needs_verification_v1"
    private let lastVerificationDateKey = "shift_last_verification_date_v1"

    // MARK: - Core Methods

    /// بدء معالج التحقق
    /// - Parameters:
    ///   - reason: سبب التحقق (نتيجة التحقق الفاشلة)
    ///   - phases: النوبات المتاحة للاختيار
    func startVerification(
        reason: ReferenceDateValidator.ValidationResult,
        availablePhases: [ShiftPhase]
    ) {
        Self.logger.info("Starting verification wizard - reason: \(reason.localizedDescription)")

        self.validationResult = reason
        self.availablePhases = availablePhases.filter { $0.isVisibleInCalendar }
        self.selectedPhase = nil
        self.errorMessage = nil
        self.state = .presenting
        self.isPresented = true

        // تسجيل في Activity Log
        logCorruptionDetected(reason: reason)
    }

    /// إكمال التحقق بعد اختيار المستخدم
    /// - Parameter todayPhase: النوبة التي اختارها المستخدم
    func completeVerification(todayPhase: ShiftPhase) {
        Self.logger.info("Completing verification with phase: \(todayPhase.rawValue)")

        state = .processingSelection

        // الحصول على نظام النوبات الحالي
        guard let systemID = UserSettingsStore.shared.systemType else {
            let error = "No shift system configured"
            Self.logger.error("\(error)")
            state = .failed(error)
            errorMessage = error
            return
        }

        // الحصول على الدورة من النظام
        let engineSystemID = mapToEngineSystemID(systemID)
        let system = ShiftEngine.shared.system(for: engineSystemID)
        let phases = system.phases

        // حساب تاريخ المرجع الجديد
        guard let (newReferenceDate, newSetupIndex) = ReferenceDateValidator.shared.calculateReferenceFromToday(
            todayPhase: todayPhase,
            systemPhases: phases
        ) else {
            let error = "Failed to calculate reference date"
            Self.logger.error("\(error)")
            state = .failed(error)
            errorMessage = error
            return
        }

        // حفظ البيانات الجديدة
        saveRecoveredData(
            referenceDate: newReferenceDate,
            setupIndex: newSetupIndex,
            phase: todayPhase
        )

        // تسجيل النجاح
        logRecoveryCompleted(method: "user_verification", phase: todayPhase)

        // إنهاء المعالج
        state = .completed
        clearNeedsVerificationFlag()

        // إغلاق بعد تأخير قصير للتأكيد البصري
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isPresented = false
            self?.state = .idle
        }

        Self.logger.info("Verification completed successfully")
    }

    /// إغلاق المعالج بدون إكمال (استخدام آخر حالة معروفة أو إعادة الإعداد)
    func dismiss(useFallback: Bool = true) {
        Self.logger.warning("Wizard dismissed without completion - useFallback: \(useFallback)")

        if useFallback {
            // محاولة استخدام النسخة الاحتياطية
            let (backupDate, backupIndex) = ReferenceDateValidator.shared.loadBackup()

            if let date = backupDate, let index = backupIndex {
                Self.logger.info("Using backup data for recovery")
                saveRecoveredData(
                    referenceDate: date,
                    setupIndex: index,
                    phase: nil
                )
                logRecoveryCompleted(method: "backup_restore", phase: nil)
            } else {
                // لا توجد نسخة احتياطية - وضع علامة "يحتاج تحقق"
                Self.logger.warning("No backup available - marking as needs verification")
                setNeedsVerificationFlag()
                logRecoveryFailed()
            }
        } else {
            setNeedsVerificationFlag()
        }

        state = .dismissed
        isPresented = false
    }

    /// التحقق مما إذا كان التطبيق يحتاج تحقق
    var needsVerification: Bool {
        UserDefaults.standard.bool(forKey: needsVerificationKey)
    }

    // MARK: - Private Helpers

    private func mapToEngineSystemID(_ type: ShiftSystemType) -> ShiftSystemID {
        switch type {
        case .threeShiftTwoOff: return .threeShiftTwoOff
        case .twentyFourFortyEight: return .twentyFourFortyEight
        case .twoWorkFourOff: return .twoWorkFourOff
        case .standardMorning: return .standardMorning
        case .eightHourShift: return .eightHourShift
        }
    }

    private func saveRecoveredData(referenceDate: Date, setupIndex: Int, phase: ShiftPhase?) {
        // تحديث UserSettingsStore
        UserSettingsStore.shared.referenceDate = referenceDate
        UserSettingsStore.shared.setupIndex = setupIndex
        if let phase = phase {
            UserSettingsStore.shared.startPhase = phase
        }

        // إنشاء وحفظ البصمة الجديدة
        let checksum = ReferenceDateValidator.shared.generateChecksum(
            date: referenceDate,
            setupIndex: setupIndex
        )
        ReferenceDateValidator.shared.saveChecksum(checksum)

        // حفظ نسخة احتياطية
        ReferenceDateValidator.shared.saveBackup(
            referenceDate: referenceDate,
            setupIndex: setupIndex
        )

        // إعادة بناء الإشعارات
        if let context = UserSettingsStore.shared.shiftContext {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: UserShift.shared.allManualOverrides
            )
        }

        Self.logger.info("Recovered data saved: date=\(referenceDate), index=\(setupIndex)")
    }

    private func setNeedsVerificationFlag() {
        UserDefaults.standard.set(true, forKey: needsVerificationKey)
    }

    private func clearNeedsVerificationFlag() {
        UserDefaults.standard.set(false, forKey: needsVerificationKey)
        UserDefaults.standard.set(Date(), forKey: lastVerificationDateKey)
    }

    // MARK: - Activity Log Integration

    private func logCorruptionDetected(reason: ReferenceDateValidator.ValidationResult) {
        let message = SystemMessage(
            sourceType: .shift,
            sourceID: nil,
            kind: .referenceDateCorruptionDetected(reason: reason.localizedDescription),
            date: Date()
        )
        MessagesStore.shared.add(message)
    }

    private func logRecoveryCompleted(method: String, phase: ShiftPhase?) {
        let phaseInfo = phase?.rawValue ?? "backup"
        let message = SystemMessage(
            sourceType: .shift,
            sourceID: nil,
            kind: .referenceDateRecovered(method: "\(method):\(phaseInfo)"),
            date: Date()
        )
        MessagesStore.shared.add(message)
    }

    private func logRecoveryFailed() {
        let message = SystemMessage(
            sourceType: .shift,
            sourceID: nil,
            kind: .referenceDateResetRequired,
            date: Date()
        )
        MessagesStore.shared.add(message)
    }
}

// MARK: - Extension for Convenience

extension ShiftVerificationWizard {

    /// الحصول على عنوان المعالج المترجم
    var title: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        return isArabic ? "التحقق من جدول النوبات" : "Verify Shift Schedule"
    }

    /// الحصول على الرسالة الرئيسية المترجمة
    var message: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        return isArabic
            ? "جدول نوبتك يحتاج للتحقق. ما هي نوبتك اليوم؟"
            : "Your shift schedule needs to be verified. What shift do you have today?"
    }

    /// الحصول على نص زر التأكيد المترجم
    var confirmButtonTitle: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        return isArabic ? "تأكيد" : "Confirm"
    }

    /// الحصول على نص زر الإغلاق المترجم
    var dismissButtonTitle: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
        return isArabic ? "لاحقاً" : "Later"
    }
}
