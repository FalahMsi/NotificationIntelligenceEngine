import Foundation

/// StandardMorningSchedule
/// نظام الدوام الصباحي الرسمي (حكومي).
/// تم التحديث: إضافة "منطق الوقت" (Time Logic) لضبط الـ 7 ساعات بدقة.
struct StandardMorningSchedule: ShiftSystemProtocol {

    // MARK: - Identity
    var kind: ShiftSystemKind { .fixedWeek }

    // MARK: - Metadata
    var systemName: String {
        isArabic ? "الدوام الصباحي" : "Standard Morning"
    }
    
    var supportsNightShift: Bool { false }
    
    // ✅ ٧ ساعات عمل فقط
    var workHoursPerShift: Int { 7 }

    // النظام الصباحي لا يعتمد على مراحل دورية ثابتة
    var phases: [ShiftPhase] { [] }
    
    // MARK: - 🧠 Time Logic (The New Brain)
    
    /// تحديد متى تبدأ النوبة
    func startOffset(for phase: ShiftPhase) -> Int {
        // الدوام الصباحي يبدأ دائماً مع ساعة المستخدم (ساعة الصفر).
        return 0
    }
    
    /// تحديد مدة النوبة
    func duration(for phase: ShiftPhase) -> Int {
        // نوبة الصباح مدتها 7 ساعات
        if phase == .morning {
            return 7
        }
        return 0
    }
    
    // MARK: - Private Helpers
    private var isArabic: Bool {
        UserSettingsStore.shared.language == .arabic
    }

    // MARK: - Initial Setup
    func availableStartOptions() -> [ShiftStartOption] {
        // لا يوجد خيارات بدء لأن الجدول ثابت بالأيام
        []
    }

    // MARK: - Engine Core logic
    func buildTimeline(
        context: ShiftContext,
        from startDate: Date,
        days: Int
    ) -> ShiftTimeline {

        var items: [ShiftTimeline.Item] = []
        
        // استخدام تقويم يتبع إعدادات المستخدم لضمان دقة أيام الأسبوع
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        calendar.timeZone = .current

        let baseDate = calendar.startOfDay(for: startDate)

        for offset in 0..<days {
            guard let currentDate = calendar.date(byAdding: .day, value: offset, to: baseDate) else {
                continue
            }

            // 1 = الأحد، ... 6 = الجمعة، 7 = السبت
            let weekday = calendar.component(.weekday, from: currentDate)
            
            let phase: ShiftPhase
            
            // 1. التحقق من عطلة نهاية الأسبوع (الجمعة 6 والسبت 7)
            if weekday == 6 || weekday == 7 {
                phase = .off
            } else {
                // 2. التحقق من العطلات الرسمية
                if ShiftEngine.shared.isOfficialHoliday(currentDate) {
                    phase = .off
                } else {
                    phase = .morning
                }
            }

            items.append(
                ShiftTimeline.Item(
                    date: currentDate,
                    phase: phase
                )
            )
        }

        return ShiftTimeline(items: items)
    }
}