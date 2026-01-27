import Foundation

/// CalendarEvent
/// يمثل حدثًا قادمًا من تقويم الجهاز (EventKit)
/// مصمم ليكون خفيفاً وسريعاً في عمليات المقارنة والعرض.
struct CalendarEvent: Identifiable, Hashable {

    /// المعرّف الأصلي من EventKit (Stable Identity)
    let id: String

    /// عنوان المناسبة
    let title: String

    /// وقت بداية الحدث
    let startDate: Date

    /// وقت نهاية الحدث
    let endDate: Date

    /// هل الحدث يستمر طوال اليوم
    let isAllDay: Bool

    /// نوع النظام المرتبط (اختياري)
    let systemType: ShiftSystemID?

    // MARK: - UI Helpers
    
    /// توليد نص الوقت (مثلاً "10:00 ص" أو "طوال اليوم")
    var timeRangeString: String {
        if isAllDay {
            let isArabic = UserDefaults.standard.string(forKey: "app_language") == "ar"
            return isArabic ? "طوال اليوم" : "All Day"
        }
        
        let formatter = DateFormatter()
        // Phase 2: Use explicit 24-hour format with Latin digits
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }

    // MARK: - Identity-based Equatable
    // المقارنة بالـ ID فقط تجعل التحديثات في SwiftUI أسرع بكثير
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
