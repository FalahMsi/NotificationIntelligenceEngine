import Foundation

/// ShiftSystemID
/// معرف رسمي لكل نظام نوبات داخل ShiftEngine
///
/// يُستخدم في:
/// - التخزين (Codable)
/// - الربط مع ShiftEngine
/// - العرض في الإعدادات (UI Only)
///
/// ❌ لا يحتوي أي منطق حساب
enum ShiftSystemID: String, Identifiable, CaseIterable, Codable, Hashable {

    case threeShiftTwoOff
    case twentyFourFortyEight
    case twoWorkFourOff
    case standardMorning
    case eightHourShift

    // MARK: - Identifiable
    var id: String { rawValue }
    
    // MARK: - Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Display (Full Title – Settings / Setup)

    /// عنوان كامل للعرض في شاشات الإعداد
    /// نصوص صريحة (Locale-safe)
    var title: String {
        switch self {
        case .threeShiftTwoOff:
            return isArabic ? "ثلاثة بـ(يومين)" : "3 Shifts, 2 Off"
            
        case .twentyFourFortyEight:
            return isArabic ? "يوم بـ(يومين)" : "24h Work, 48h Off"
            
        case .twoWorkFourOff:
            return isArabic ? "يومين بـ(أربعة)" : "2 Work, 4 Off"
            
        case .standardMorning:
            return isArabic ? "صبـاحي" : "Standard Morning"
            
        case .eightHourShift:
            return isArabic ? "يومين(صبح،عصر،ليل)، بـ(يومين)" : "8-Hour Rotation (2 Days On, 2 Off)"
        }
    }
}

// MARK: - Short Display Name (Reports / Compact UI)

extension ShiftSystemID {

    /// اسم مختصر للعرض في التقارير والواجهات الضيقة
    /// UI Only
    var displayName: String {
        switch self {
        case .threeShiftTwoOff:
            return isArabic ? "ثلاثة بـ(يومين)" : "3 - 2 System"
            
        case .twentyFourFortyEight:
            return isArabic ? "يوم بـ(يومين)" : "24 / 48"
            
        case .twoWorkFourOff:
            return isArabic ? "يومين بـ(أربعة)" : "2 - 4 System"
            
        case .standardMorning:
            return isArabic ? "صبـاحي" : "Morning"
            
        case .eightHourShift:
            return isArabic ? "8 ساعات" : "8-Hour Shift"
        }
    }
}
