import Foundation

/// ThreeShiftTwoOffSystem
/// نظام الدورة الخماسية: صبح - عصر - ليل - راحة - راحة.
/// تم التحديث: تصحيح اسم العنصر إلى ShiftTimeline.Item
struct ThreeShiftTwoOffSystem: ShiftSystemProtocol {

    // MARK: - Identity
    var kind: ShiftSystemKind { .cyclic }
    
    // MARK: - Metadata
    var systemName: String {
        isArabic ? "نظام ٣ أيام بيومين" : "3 Shifts / 2 Off System"
    }
    
    var supportsNightShift: Bool { true }
    
    // العرض العام للساعات
    var workHoursPerShift: Int { 8 }

    // الدورة: [0:صبح، 1:عصر، 2:ليل، 3:راحة، 4:راحة]
    var phases: [ShiftPhase] {
        [.morning, .evening, .night, .off, .off]
    }
    
    // MARK: - 🧠 Time Logic (The New Brain)
    
    /// تحديد متى تبدأ كل نوبة نسبةً إلى "ساعة الصفر"
    func startOffset(for phase: ShiftPhase) -> Int {
        switch phase {
        case .morning: return 0   // تبدأ فوراً مع ساعة المستخدم
        case .evening: return 8   // تبدأ بعد 8 ساعات
        case .night:   return 16  // تبدأ بعد 16 ساعة
        default:       return 0
        }
    }
    
    /// تحديد مدة كل نوبة
    func duration(for phase: ShiftPhase) -> Int {
        return 8
    }
    
    // MARK: - Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Start Options
    func availableStartOptions() -> [ShiftStartOption] {
        let options: [(Int, String, ShiftPhase)] = [
            (0, isArabic ? "دوام صباح" : "Morning Shift", .morning),
            (1, isArabic ? "دوام عصر" : "Afternoon Shift", .evening),
            (2, isArabic ? "دوام ليل" : "Night Shift", .night),
            (3, isArabic ? "أول يوم راحة" : "1st Off Day", .off),
            (4, isArabic ? "ثاني يوم راحة" : "2nd Off Day", .off)
        ]
        
        return options.map { ShiftStartOption(id: $0.0, title: $0.1, phase: $0.2) }
    }

    // MARK: - Engine Logic
    func buildTimeline(context: ShiftContext, from startDate: Date, days: Int) -> ShiftTimeline {
        
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        calendar.timeZone = .current

        // تحديد نقطة الانطلاق
        let startingIndex: Int
        if let setupIndex = context.setupIndex {
            startingIndex = setupIndex % phases.count
        } else if let startPhase = context.startPhase {
            startingIndex = phases.firstIndex(of: startPhase) ?? 0
        } else {
            startingIndex = 0
        }

        let normalizedReference = calendar.startOfDay(for: context.referenceDate)
        let normalizedStartRange = calendar.startOfDay(for: startDate)
        
        // ✅ التصحيح هنا: استخدام ShiftTimeline.Item بدلاً من ShiftTimelineItem
        var items: [ShiftTimeline.Item] = []
        
        let cycleCount = phases.count // 5
        
        for offset in 0..<days {
            guard let currentDate = calendar.date(byAdding: .day, value: offset, to: normalizedStartRange) else {
                continue
            }
            
            // حساب الفرق الزمني بالأيام
            let diffInDays = calendar.dateComponents([.day], from: normalizedReference, to: currentDate).day ?? 0
            
            // المعادلة الدورية
            let rawIndex = (startingIndex + diffInDays) % cycleCount
            let finalIndex = rawIndex >= 0 ? rawIndex : (rawIndex + cycleCount)
            
            // ✅ التصحيح هنا أيضاً
            items.append(ShiftTimeline.Item(date: currentDate, phase: phases[finalIndex]))
        }
        
        return ShiftTimeline(items: items)
    }
}
