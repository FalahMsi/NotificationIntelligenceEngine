import SwiftUI

/// ManualLeaveType
/// يحدد نوع الإجازة وتصنيفها وألوانها (مصطلحات ديوان الخدمة المدنية)
enum ManualLeaveType: String, CaseIterable, Codable, Identifiable {
    
    // ⚠️ القيم النصية هنا تستخدم للحفظ، قمنا بتنقيحها لتكون رسمية
    case regularLeave = "إجازة دورية"
    case sickLeave = "إجازة مرضية"
    case emergencyLeave = "إجازة طارئة" // أو "عرضية" حسب المتبع، الطارئة أكثر رسمية
    case allowance = "راحة بدل عمل"      // تعديل: لتمييزها عن البدل المالي
    case off = "راحة"                    // تعديل: تبسيط المسمى
    case compensation = "راحة تعويضية"   // تعديل: اسم أكثر دقة
    case study = "إجازة دراسية"
    case other = "أخرى"

    var id: String { rawValue }

    /// ✅ الاسم المعروض (يدعم الترجمة الرسمية)
    var localizedName: String {
        let language = UserSettingsStore.shared.language
        
        switch language {
        case .arabic:
            return self.rawValue
        case .english:
            switch self {
            case .regularLeave:   return "Annual Leave"
            case .sickLeave:      return "Sick Leave"
            case .emergencyLeave: return "Emergency Leave"
            case .allowance:      return "Rest in Lieu"
            case .off:            return "Rest Day"
            case .compensation:   return "Compensatory Rest"
            case .study:          return "Study Leave"
            case .other:          return "Other"
            }
        }
    }

    /// اللون المميز (تم ضبط الألوان لتكون أكثر هدوءاً ورسمية)
    var color: Color {
        switch self {
        case .regularLeave:   return .blue
        case .sickLeave:      return .red.opacity(0.8)
        case .emergencyLeave: return .orange
        case .allowance:      return .purple
        case .off:            return .gray
        case .compensation:   return .green
        case .study:          return .indigo
        case .other:          return .brown
        }
    }
    
    /// هل يخصم من رصيد أيام العمل؟
    var isDeductible: Bool {
        switch self {
        case .allowance, .off, .compensation:
            return false // أنواع الراحات لا تخصم
        default:
            return true  // الإجازات تخصم
        }
    }
    
    /// الأولوية في العرض
    var priority: Int {
        switch self {
        case .sickLeave, .emergencyLeave: return 100
        case .regularLeave: return 80
        default: return 50
        }
    }
}

/// ManualLeave
/// يمثل فترة الإجازة (من تاريخ إلى تاريخ)
struct ManualLeave: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date
    var type: ManualLeaveType
    var note: String?
    var createdAt: Date = Date()

    init(startDate: Date, endDate: Date, type: ManualLeaveType, note: String? = nil) {
        let calendar = Calendar.current
        self.startDate = calendar.startOfDay(for: startDate)
        self.endDate = calendar.startOfDay(for: endDate)
        self.type = type
        self.note = note
    }
    
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)
        return target >= startDate && target <= endDate
    }
    
    var totalDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
}
