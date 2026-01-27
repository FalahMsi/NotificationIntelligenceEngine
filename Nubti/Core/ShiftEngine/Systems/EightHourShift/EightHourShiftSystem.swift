import Foundation

/// EightHourShiftSystem
/// نظام الـ ٨ ساعات المتغير: يومين صباح، يومين عصر، يومين ليل، يومين راحة.
/// تم التحديث: إضافة "منطق الوقت" (Time Logic) ليتوافق مع العقل الجديد.
struct EightHourShiftSystem: ShiftSystemProtocol {
    
    // MARK: - Identity
    var kind: ShiftSystemKind { .cyclic }
    
    var systemName: String {
        isArabic ? "يومين (صبح، عصر، ليل) بـ يومين" : "8-Hour Rotation (2M, 2E, 2N, 2Off)"
    }
    
    var supportsNightShift: Bool { true }
    
    // العرض العام
    var workHoursPerShift: Int { 8 }

    // دورة النظام الثابتة: ٨ أيام
    var phases: [ShiftPhase] {
        [.morning, .morning, .evening, .evening, .night, .night, .off, .off]
    }
    
    // MARK: - 🧠 Time Logic (The New Brain)
    
    /// تحديد إزاحة الوقت لكل نوبة
    func startOffset(for phase: ShiftPhase) -> Int {
        switch phase {
        case .morning: return 0   // تبدأ مع ساعة المستخدم
        case .evening: return 8   // تبدأ بعد 8 ساعات
        case .night:   return 16  // تبدأ بعد 16 ساعة
        default:       return 0
        }
    }
    
    /// تحديد مدة النوبة
    func duration(for phase: ShiftPhase) -> Int {
        // جميع نوبات هذا النظام مدتها 8 ساعات
        return 8
    }
    
    // MARK: - Private Helpers
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Initial Setup Options
    func availableStartOptions() -> [ShiftStartOption] {
        let options: [(Int, String, ShiftPhase)] = [
            (0, isArabic ? "أول يوم صباح" : "1st Day Morning", .morning),
            (1, isArabic ? "ثاني يوم صباح" : "2nd Day Morning", .morning),
            (2, isArabic ? "أول يوم عصر" : "1st Day Evening", .evening),
            (3, isArabic ? "ثاني يوم عصر" : "2nd Day Evening", .evening),
            (4, isArabic ? "أول يوم ليل" : "1st Day Night", .night),
            (5, isArabic ? "ثاني يوم ليل" : "2nd Day Night", .night),
            (6, isArabic ? "أول يوم راحة" : "1st Day Off", .off),
            (7, isArabic ? "ثاني يوم راحة" : "2nd Day Off", .off)
        ]
        
        return options.map { ShiftStartOption(id: $0.0, title: $0.1, phase: $0.2) }
    }
    
    // MARK: - Engine Core logic
    func buildTimeline(context: ShiftContext, from startDate: Date, days: Int) -> ShiftTimeline {
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        calendar.timeZone = .current

        // 1. تحديد نقطة البداية
        let startingIndex: Int
        if let setupID = context.setupIndex {
            startingIndex = setupID % phases.count
        } else if let phase = context.startPhase {
            startingIndex = phases.firstIndex(of: phase) ?? 0
        } else {
            return ShiftTimeline(items: [])
        }

        let baseRefDate = calendar.startOfDay(for: context.referenceDate)
        let targetStartDate = calendar.startOfDay(for: startDate)
        var items: [ShiftTimeline.Item] = []
        
        let cycleLength = phases.count // 8

        for offset in 0..<days {
            guard let currentDate = calendar.date(byAdding: .day, value: offset, to: targetStartDate) else { continue }
            
            // 2. الحساب الرياضي
            let diffInDays = calendar.dateComponents([.day], from: baseRefDate, to: currentDate).day ?? 0
            
            let rawIndex = (startingIndex + diffInDays) % cycleLength
            let safeIndex = rawIndex >= 0 ? rawIndex : (rawIndex + cycleLength)
            
            items.append(ShiftTimeline.Item(date: currentDate, phase: phases[safeIndex]))
        }

        return ShiftTimeline(items: items)
    }
}