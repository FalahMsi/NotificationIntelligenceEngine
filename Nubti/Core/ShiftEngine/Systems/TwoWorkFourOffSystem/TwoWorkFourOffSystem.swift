import Foundation

/// TwoWorkFourOffSystem
/// نظام يومين عمل (٤٨ ساعة) / ٤ أيام راحة (٩٦ ساعة).
/// تم التحديث: إضافة "منطق الوقت" (Time Logic) لضمان حساب الـ 24 ساعة بدقة.
struct TwoWorkFourOffSystem: ShiftSystemProtocol {

    // MARK: - Identity
    var kind: ShiftSystemKind { .cyclic }

    // MARK: - Metadata
    var systemName: String {
        isArabic ? "يومين عمل / ٤ أيام راحة (٤٨/٩٦)" : "2 Work / 4 Off (48/96)"
    }
    
    var supportsNightShift: Bool { true } // نعم، لأن الـ 24 ساعة تشمل الليل
    
    // العرض العام
    var workHoursPerShift: Int { 24 }

    // MARK: - Structure
    // دورة النظام: [عمل، عمل، راحة، راحة، راحة، راحة]
    // نستخدم .morning كرمز ليوم العمل الكامل (24 ساعة)
    var phases: [ShiftPhase] {
        [.morning, .morning, .off, .off, .off, .off]
    }
    
    // MARK: - 🧠 Time Logic (The New Brain)
    
    /// تحديد متى تبدأ النوبة
    func startOffset(for phase: ShiftPhase) -> Int {
        // في هذا النظام، أيام العمل تبدأ دائماً في "ساعة الصفر" التي حددها المستخدم.
        // لا يوجد إزاحة (مثل نوبة عصر أو ليل منفصلة).
        return 0
    }
    
    /// تحديد مدة النوبة
    func duration(for phase: ShiftPhase) -> Int {
        // أيام العمل مدتها 24 ساعة كاملة
        if phase.isCountedAsWorkDay {
            return 24
        }
        return 0
    }
    
    // MARK: - Translation Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Initial Setup Options
    func availableStartOptions() -> [ShiftStartOption] {
        let options: [(Int, String, ShiftPhase)] = [
            (0, isArabic ? "أول يوم عمل (٢٤س)" : "1st Work Day (24h)", .morning),
            (1, isArabic ? "ثاني يوم عمل (٢٤س)" : "2nd Work Day (24h)", .morning),
            (2, isArabic ? "أول يوم راحة" : "1st Off Day", .off),
            (3, isArabic ? "ثاني يوم راحة" : "2nd Off Day", .off),
            (4, isArabic ? "ثالث يوم راحة" : "3rd Off Day", .off),
            (5, isArabic ? "رابع يوم راحة" : "4th Off Day", .off)
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

        let normalizedReference = calendar.startOfDay(for: context.referenceDate)
        let normalizedStartRange = calendar.startOfDay(for: startDate)
        var items: [ShiftTimeline.Item] = []
        
        let cycleCount = phases.count // 6

        for offset in 0..<days {
            guard let currentDate = calendar.date(byAdding: .day, value: offset, to: normalizedStartRange) else { continue }
            
            // 2. الحساب الرياضي (Cycle Modulo)
            let diffInDays = calendar.dateComponents([.day], from: normalizedReference, to: currentDate).day ?? 0
            
            let rawIndex = (startingIndex + diffInDays) % cycleCount
            let finalIndex = rawIndex >= 0 ? rawIndex : (rawIndex + cycleCount)
            
            items.append(ShiftTimeline.Item(date: currentDate, phase: phases[finalIndex]))
        }
        
        return ShiftTimeline(items: items)
    }
}