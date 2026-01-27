import Foundation
import SwiftUI

// MARK: - Event Impact (تأثير الحدث على الرصيد)
enum ShiftEventImpact: String, Codable {
    case deduction  // خصم من الساعات (تأخير، خروج مبكر)
    case addition   // إضافة للساعات (عمل إضافي)
    case neutral    // محايد (توثيق فقط)
    
    var color: Color {
        switch self {
        case .deduction: return .red
        case .addition: return .green
        case .neutral: return .blue
        }
    }
    
    var sign: String {
        switch self {
        case .deduction: return "-"
        case .addition: return "+"
        case .neutral: return ""
        }
    }
}

// MARK: - Event Type (نوع الحدث)
enum ShiftEventType: String, Codable, CaseIterable, Identifiable {
    case lateEntry          // تأخير صباحي
    case earlyExit          // خروج مبكر
    case midShiftPermission // استئذان أثناء الدوام
    case overtime           // عمل إضافي (تمت إضافتها لإصلاح الخطأ)
    
    var id: String { rawValue }
    
    // التأثير الافتراضي
    var defaultImpact: ShiftEventImpact {
        switch self {
        case .lateEntry, .earlyExit: return .deduction
        case .overtime: return .addition
        case .midShiftPermission: return .neutral
        }
    }
    
    func localizedName(language: AppLanguage) -> String {
        let isAr = (language == .arabic)
        switch self {
        case .lateEntry: return isAr ? "استئذان بداية دوام" : "Start Permission"
        case .earlyExit: return isAr ? "استئذان نهاية دوام" : "End Permission"
        case .midShiftPermission: return isAr ? "استئذان أثناء الدوام" : "Mid-Shift Permission"
        case .overtime: return isAr ? "عمل إضافي" : "Overtime"
        }
    }
    
    var iconName: String {
        switch self {
        case .lateEntry: return "figure.walk.arrival"
        case .earlyExit: return "figure.walk.departure"
        case .midShiftPermission: return "clock.arrow.2.circlepath"
        case .overtime: return "plus.circle"
        }
    }
}

// MARK: - The Event Model (النموذج الأساسي)
struct ShiftEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date           // تاريخ اليوم المرتبط بالحدث
    let timestamp: Date      // وقت وقوع الحدث بالضبط
    let type: ShiftEventType
    let durationMinutes: Int // المدة بالدقائق
    let note: String
    
    // هل تم تجاهل هذا الحدث من الحسابات يدوياً؟
    var isIgnored: Bool = false
    
    // MARK: - Init
    init(
        id: UUID = UUID(),
        date: Date,
        timestamp: Date? = nil,
        type: ShiftEventType,
        durationMinutes: Int,
        note: String = "",
        isIgnored: Bool = false
    ) {
        self.id = id
        // توحيد التاريخ لبداية اليوم لسهولة الفلترة
        self.date = Calendar.current.startOfDay(for: date)
        self.timestamp = timestamp ?? date
        self.type = type
        self.durationMinutes = durationMinutes
        self.note = note
        self.isIgnored = isIgnored
    }
    
    // MARK: - Computed Logic
    /// التأثير الفعلي للدقائق (سالب، موجب، أو صفر) للحسابات
    var effectiveMinutes: Int {
        if isIgnored { return 0 }
        
        switch type.defaultImpact {
        case .deduction: return -durationMinutes
        case .addition: return durationMinutes
        case .neutral: return 0
        }
    }
}
