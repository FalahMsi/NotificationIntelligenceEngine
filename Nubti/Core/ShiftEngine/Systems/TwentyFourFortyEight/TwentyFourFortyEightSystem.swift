import Foundation

/// TwentyFourFortyEightSystem
/// نظام ٢٤/٤٨: يوم عمل (٢٤ ساعة) يتبعه يومين راحة.
/// تم التحديث: إضافة "منطق الوقت" (Time Logic) لضمان حساب الـ 24 ساعة بدقة.
struct TwentyFourFortyEightSystem: ShiftSystemProtocol {

    // MARK: - Identity
    var kind: ShiftSystemKind { .cyclic }

    // MARK: - Metadata
    var systemName: String {
        isArabic ? "نظام ٢٤/٤٨ (يوم بيومين)" : "24/48 System (1 Work, 2 Off)"
    }
    
    // هذا النظام يعمل ٢٤ ساعة، لذا فهو يغطي الليل والنهار
    var supportsNightShift: Bool { true }
    
    // العرض العام
    var workHoursPerShift: Int { 24 }

    // الدورة: [عمل، راحة، راحة]
    // نستخدم .morning لتمثيل يوم العمل الكامل (يبدأ صباحاً وينتهي صباح اليوم التالي)
    var phases: [ShiftPhase] {
        [.morning, .off, .off]
    }
    
    // MARK: - 🧠 Time Logic (The New Brain)
    
    /// تحديد متى تبدأ النوبة
    func startOffset(for phase: ShiftPhase) -> Int {
        // يوم العمل يبدأ دائماً مع ساعة المستخدم (ساعة الصفر).
        return 0
    }
    
    /// تحديد مدة النوبة
    func duration(for phase: ShiftPhase) -> Int {
        // إذا كان يوم عمل، فمدته 24 ساعة.
        if phase.isCountedAsWorkDay {
            return 24
        }
        return 0
    }
    
    // MARK: - Helper
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Start Options
    func availableStartOptions() -> [ShiftStartOption] {
        let w = isArabic ? "يوم العمل (٢٤ ساعة)" : "Work Day (24h)"
        let o1 = isArabic ? "أول يوم راحة" : "1st Off Day"
        let o2 = isArabic ? "ثاني يوم راحة" : "2nd Off Day"

        let options: [(Int, String, ShiftPhase)] = [
            (0, w, .morning),
            (1, o1, .off),
            (2, o2, .off)
        ]
        
        return options.map { ShiftStartOption(id: $0.0, title: $0.1, phase: $0.2) }
    }

    // MARK: - Engine Logic
    func buildTimeline(context: ShiftContext, from startDate: Date, days: Int) -> ShiftTimeline {
        
        // 1. إعداد التقويم بدقة
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        calendar.timeZone = .current

        // 2. تحديد نقطة البداية
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
        var items: [ShiftTimeline.Item] = []
        
        let cycleCount = phases.count // 3
        
        for offset in 0..<days {
            guard let currentDate = calendar.date(byAdding: .day, value: offset, to: normalizedStartRange) else {
                continue
            }
            
            // 3. حساب الفرق الزمني
            let diffInDays = calendar.dateComponents([.day], from: normalizedReference, to: currentDate).day ?? 0
            
            // 4. المعادلة الرياضية للدورة الثلاثية
            let rawIndex = (startingIndex + diffInDays) % cycleCount
            let finalIndex = rawIndex >= 0 ? rawIndex : (rawIndex + cycleCount)
            
            items.append(ShiftTimeline.Item(date: currentDate, phase: phases[finalIndex]))
        }
        
        return ShiftTimeline(items: items)
    }
}