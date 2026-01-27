import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - App Language
enum AppLanguage: String, CaseIterable, Codable {
    case arabic = "ar"
    case english = "en"
    
    var direction: LayoutDirection {
        switch self {
        case .arabic: return .rightToLeft
        case .english: return .leftToRight
        }
    }
    
    var displayName: String {
        switch self {
        case .arabic: return "العربية"
        case .english: return "English"
        }
    }
}

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable {
    case system, light, dark
    
    // دعم الترجمة للمظهر
    var localizedName: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        switch self {
        case .system: return isArabic ? "تلقائي" : "System"
        case .light:  return isArabic ? "نهاري" : "Light"
        case .dark:   return isArabic ? "ليلي" : "Dark"
        }
    }
}

// MARK: - ShiftSystemType
enum ShiftSystemType: String, Codable, CaseIterable {
    case threeShiftTwoOff
    case twentyFourFortyEight
    case twoWorkFourOff
    case standardMorning
    case eightHourShift

    // دعم الترجمة لمسميات الأنظمة
    var displayName: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        switch self {
        case .threeShiftTwoOff:     return isArabic ? "ثلاثة بـ(يومين)" : "3 Shifts / 2 Off"
        case .twentyFourFortyEight: return isArabic ? "يوم بـ(يومين)" : "1 Day / 2 Off"
        case .twoWorkFourOff:       return isArabic ? "يومين بـ(أربعة)" : "2 Days / 4 Off"
        case .standardMorning:      return isArabic ? "دوام صباحي" : "Morning Schedule"
        case .eightHourShift:       return isArabic ? "يومين (صبح، عصر، ليل) بـ يومين" : "8-Hour Rotation"
        }
    }
}

@MainActor
final class UserSettingsStore: ObservableObject {

    static let shared = UserSettingsStore()
    private var isInitialized = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app", category: "Settings")

    // MARK: - Published Properties
    
    @Published var language: AppLanguage { didSet { save() } }
    @Published var appearanceMode: AppearanceMode { didSet { save() } }
    @Published var isSetupComplete: Bool { didSet { save() } }
    @Published var systemType: ShiftSystemType? { didSet { save() } }
    @Published var startPhase: ShiftPhase? { didSet { save() } }
    @Published var setupIndex: Int? { didSet { save() } }
    @Published var shiftStartTime: DateComponents? { didSet { save() } }
    @Published var shiftEndTime: DateComponents? { didSet { save() } }
    @Published var referenceDate: Date? { didSet { save() } }

    @Published var notificationsEnabled: Bool {
        didSet {
            save()
            if isInitialized { handleNotificationToggle() }
        }
    }

    @Published var systemCalendarIntegrationEnabled: Bool {
        didSet {
            save()
            if isInitialized { handleCalendarIntegrationToggle() }
        }
    }

    // MARK: - Derived Properties
    
    var workStartHour: Int {
        resolvedShiftStartTime.hour ?? 6
    }

    private var resolvedShiftStartTime: DateComponents {
        if let shiftStartTime, (shiftStartTime.hour != nil || shiftStartTime.minute != nil) {
            return shiftStartTime
        }
        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 0
        return comps
    }

    private var resolvedShiftEndTime: DateComponents {
        if let shiftEndTime, (shiftEndTime.hour != nil || shiftEndTime.minute != nil) {
            return shiftEndTime
        }
        // Default: 7 hours after start (7:00 + 7h = 14:00)
        var comps = DateComponents()
        comps.hour = 14
        comps.minute = 0
        return comps
    }

    /// حساب مدة الدوام بالساعات من وقت البدء والانتهاء.
    /// يدعم النوبات التي تعبر منتصف الليل (مثل 23:00 → 07:00 = 8 ساعات).
    ///
    /// # Cross-Midnight Handling
    /// - If endHour > startHour: duration = endHour - startHour (normal case)
    /// - If endHour <= startHour: duration = (24 - startHour) + endHour (overnight)
    ///
    /// # Examples
    /// - 07:00 → 14:00 = 7 hours (normal)
    /// - 23:00 → 07:00 = 8 hours (overnight)
    /// - 15:00 → 23:00 = 8 hours (evening)
    var workDurationHours: Int {
        let startHour = resolvedShiftStartTime.hour ?? 7
        let endHour = resolvedShiftEndTime.hour ?? 14

        // Handle cross-midnight shifts
        if endHour > startHour {
            // Normal case: shift doesn't cross midnight
            return endHour - startHour
        } else if endHour < startHour {
            // Cross-midnight: e.g., 23:00 → 07:00 = (24 - 23) + 7 = 8 hours
            return (24 - startHour) + endHour
        } else {
            // startHour == endHour: could be 24-hour shift or invalid config
            // Assume 24-hour shift if explicitly set, otherwise return default
            return 24
        }
    }

    private var resolvedReferenceDate: Date {
        Calendar.current.startOfDay(for: referenceDate ?? Date())
    }

    /// تحويل البيانات المخزنة إلى سياق شفت جاهز للمحرك
    var shiftContext: ShiftContext? {
        guard let systemType else { return nil }

        let engineSystemID: ShiftSystemID
        switch systemType {
        case .threeShiftTwoOff:       engineSystemID = .threeShiftTwoOff
        case .twentyFourFortyEight:   engineSystemID = .twentyFourFortyEight
        case .twoWorkFourOff:         engineSystemID = .twoWorkFourOff
        case .standardMorning:        engineSystemID = .standardMorning
        case .eightHourShift:         engineSystemID = .eightHourShift
        }

        // ✅ FIX: تمرير مدة العمل للأنظمة التي تدعم تخصيص المستخدم (Morning)
        // الأنظمة الدورية تستخدم مدة ثابتة من ShiftSystemProtocol.duration()
        let userDuration: Int?
        if systemType == .standardMorning {
            userDuration = workDurationHours
        } else {
            userDuration = nil // Cyclic systems use fixed durations
        }

        return ShiftContext(
            systemID: engineSystemID,
            startPhase: startPhase,
            setupIndex: setupIndex,
            shiftStartTime: resolvedShiftStartTime,
            referenceDate: resolvedReferenceDate,
            workDurationHours: userDuration
        )
    }

    // MARK: - Init
    private init() {
        let defaults = UserDefaults.standard
        
        // التحميل الآمن للبيانات مع قيم افتراضية
        self.language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .arabic
        self.appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? .light
        self.isSetupComplete = defaults.bool(forKey: Keys.isSetupComplete)
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.systemCalendarIntegrationEnabled = defaults.bool(forKey: Keys.systemCalendarIntegrationEnabled)
        self.referenceDate = defaults.object(forKey: Keys.referenceDate) as? Date
        
        if defaults.object(forKey: Keys.setupIndex) != nil {
            self.setupIndex = defaults.integer(forKey: Keys.setupIndex)
        } else {
            self.setupIndex = nil
        }

        if let raw = defaults.string(forKey: Keys.systemType) {
            self.systemType = ShiftSystemType(rawValue: raw)
        }

        if let data = defaults.data(forKey: Keys.startPhase) {
            self.startPhase = try? JSONDecoder().decode(ShiftPhase.self, from: data)
        }

        if let data = defaults.data(forKey: Keys.shiftStartTime) {
            self.shiftStartTime = try? JSONDecoder().decode(DateComponents.self, from: data)
        }

        if let data = defaults.data(forKey: Keys.shiftEndTime) {
            self.shiftEndTime = try? JSONDecoder().decode(DateComponents.self, from: data)
        }

        // V2/Phase 6: Perform migration if needed
        performMigrationIfNeeded()

        self.isInitialized = true
    }

    // MARK: - Persistence
    private func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
        defaults.set(isSetupComplete, forKey: Keys.isSetupComplete)
        defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(systemCalendarIntegrationEnabled, forKey: Keys.systemCalendarIntegrationEnabled)
        defaults.set(systemType?.rawValue, forKey: Keys.systemType)
        defaults.set(referenceDate, forKey: Keys.referenceDate)

        if let setupIndex {
            defaults.set(setupIndex, forKey: Keys.setupIndex)
        } else {
            defaults.removeObject(forKey: Keys.setupIndex)
        }

        if let startPhase {
            defaults.set(try? JSONEncoder().encode(startPhase), forKey: Keys.startPhase)
        } else {
            defaults.removeObject(forKey: Keys.startPhase)
        }

        if let shiftStartTime {
            defaults.set(try? JSONEncoder().encode(shiftStartTime), forKey: Keys.shiftStartTime)
        } else {
            defaults.removeObject(forKey: Keys.shiftStartTime)
        }

        if let shiftEndTime {
            defaults.set(try? JSONEncoder().encode(shiftEndTime), forKey: Keys.shiftEndTime)
        } else {
            defaults.removeObject(forKey: Keys.shiftEndTime)
        }
    }

    private enum Keys {
        static let language = "app_language"
        static let appearanceMode = "appearanceMode"
        static let isSetupComplete = "isSetupComplete"
        static let notificationsEnabled = "notificationsEnabled"
        static let systemCalendarIntegrationEnabled = "systemCalendarIntegrationEnabled"
        static let systemType = "systemType"
        static let startPhase = "startPhase"
        static let setupIndex = "setupIndex"
        static let shiftStartTime = "shiftStartTime"
        static let shiftEndTime = "shiftEndTime"
        static let referenceDate = "referenceDate"
        // V2: Notification Config Versioning
        static let notificationConfigVersion = "notification_config_version"
    }

    // MARK: - Migration (V2/Phase 6)

    /// Current notification config version
    private static let currentNotificationConfigVersion = 2

    /// Perform migration from V1 to V2 if needed
    private func performMigrationIfNeeded() {
        let defaults = UserDefaults.standard
        let savedVersion = defaults.integer(forKey: Keys.notificationConfigVersion)

        // Skip if already at current version
        guard savedVersion < Self.currentNotificationConfigVersion else { return }

        logger.info("📦 [Migration] Upgrading notification config from v\(savedVersion) to v\(Self.currentNotificationConfigVersion)")

        // V1 → V2 Migration
        if savedVersion < 2 {
            migrateToV2()
        }

        // Save current version
        defaults.set(Self.currentNotificationConfigVersion, forKey: Keys.notificationConfigVersion)
    }

    /// V1 → V2 Migration
    /// - Ensures V1 users see no change on upgrade
    /// - Sets up default V2 config with advanced features disabled
    private func migrateToV2() {
        let defaults = UserDefaults.standard

        // Check if user had notifications enabled in V1
        let hadNotificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)

        if hadNotificationsEnabled {
            // Preserve V1 behavior: set "Essential" preset flags
            // This ensures entry notification continues to work as before
            if defaults.object(forKey: "enable_punch_in") == nil {
                defaults.set(true, forKey: "enable_punch_in")
            }
            if defaults.object(forKey: "punch_in_offset") == nil {
                defaults.set(30, forKey: "punch_in_offset")
            }
        }

        // Initialize V2 advanced config with defaults (all advanced features off)
        // This ensures existing users don't see any new behavior unless they opt in
        let existingConfig = NotificationConfigStore.shared.load()
        if existingConfig.version < 1 {
            // Fresh install or V1 user - save default config
            var config = NotificationAdvancedConfig.default
            config.global.preDayReminderEnabled = false // Explicitly off for existing users
            NotificationConfigStore.shared.save(config)
        }

        logger.info("✅ [Migration] V1 → V2 complete. Advanced features disabled by default.")
    }

    // MARK: - Handlers
    
    /// التعامل مع تغيير زر تفعيل الإشعارات
    private func handleNotificationToggle() {
        if notificationsEnabled {
            NotificationService.shared.requestAuthorization()
            if let context = shiftContext {
                // إعادة بناء الإشعارات مع الأخذ بعين الاعتبار التعديلات اليدوية
                NotificationService.shared.rebuildShiftNotifications(
                    context: context,
                    manualOverrides: UserShift.shared.allManualOverrides
                )
            }
        } else {
            NotificationService.shared.cancelAllShiftNotifications()
        }
    }

    private func handleCalendarIntegrationToggle() {
        // يتم التعامل معه بشكل منفصل في SystemCalendarService
        // ولكن يمكن إضافة منطق إضافي هنا إذا لزم الأمر
    }
}
