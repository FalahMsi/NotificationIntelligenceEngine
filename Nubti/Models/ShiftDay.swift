import Foundation

/// ShiftDay
/// نموذج يوم واحد لعرض التقويم
struct ShiftDay: Identifiable, Hashable {

    let id = UUID()
    let date: Date
    let shiftPhase: ShiftPhase
    var isManualOverride: Bool = false
    let calendarEvents: [CalendarEvent]

    // MARK: - Calendar
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    // MARK: - Init
    init(
        date: Date,
        shiftPhase: ShiftPhase,
        calendarEvents: [CalendarEvent] = []
    ) {
        self.date = Self.calendar.startOfDay(for: date)
        self.shiftPhase = shiftPhase
        self.calendarEvents = calendarEvents
    }

    // MARK: - Empty State (For Grid Padding)
    /// لتحديد الأيام الفارغة في شبكة التقويم
    var isEmpty: Bool {
        date == Date.distantPast
    }

    static var empty: ShiftDay {
        ShiftDay(date: Date.distantPast, shiftPhase: .off, calendarEvents: [])
    }
}

// MARK: - Display Helpers
extension ShiftDay {
    
    /// هل هو يوم عمل فعلي؟ (يُستخدم لتمييز أيام العمل عن الراحة)
    var isWorkDay: Bool {
        shiftPhase.isCountedAsWorkDay
    }

    /// هل يجب عرضه في التقويم؟ (يستثني الحالات المخفية إن وجدت)
    var isVisible: Bool {
        shiftPhase.isVisibleInCalendar
    }

    /// العنوان المعروض (مترجم آلياً حسب لغة التطبيق)
    var displayName: String {
        shiftPhase.displayName
    }
}
