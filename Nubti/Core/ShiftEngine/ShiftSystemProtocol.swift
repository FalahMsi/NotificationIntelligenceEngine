import Foundation

/// ShiftSystemProtocol
/// العقد الموحد الذي يجب أن تلتزم به جميع أنظمة النوبات في التطبيق.
/// تم التحديث: إضافة "منطق الوقت" (Time Logic) لتمكين النظام من تحديد أوقاته بنفسه.
protocol ShiftSystemProtocol {
    
    // MARK: - Identity & Metadata
    var kind: ShiftSystemKind { get }
    var systemName: String { get }
    var supportsNightShift: Bool { get }
    
    // MARK: - Time Configuration (General)
    /// عدد ساعات العمل الافتراضية للنظام (للعرض العام)
    var workHoursPerShift: Int { get }
    
    /// مدة النوبة بالدقائق (للحسابات)
    var workDurationMinutes: Int { get }
    
    // MARK: - Time Logic (The New Brain 🧠)
    // هذه الدوال هي "القلب النابض" الجديد لدقة الوقت
    
    /// يحدد "إزاحة البداية" لكل نوبة عن وقت المستخدم الرئيسي (ساعة الصفر).
    /// - Parameter phase: النوبة (صباح، ليل، عصر...).
    /// - Returns: عدد الساعات التي يجب إضافتها لوقت البدء.
    /// - مثال: في نظام 12 ساعة، نوبة الليل تكون الإزاحة 12. في نظام 8 ساعات، تكون 16.
    func startOffset(for phase: ShiftPhase) -> Int
    
    /// يحدد مدة العمل الخاصة بنوبة معينة.
    /// عادة تكون مساوية لـ workHoursPerShift، لكن بعض الأنظمة قد تخلط (يوم طويل ويوم قصير).
    func duration(for phase: ShiftPhase) -> Int
    
    // MARK: - Flexibility Rules
    var allowsFlexibility: Bool { get }
    var supportsFlexSettings: Bool { get }
    
    // MARK: - Configuration
    var phases: [ShiftPhase] { get }
    func availableStartOptions() -> [ShiftStartOption]
    
    // MARK: - Engine
    func buildTimeline(
        context: ShiftContext,
        from startDate: Date,
        days: Int
    ) -> ShiftTimeline
}

// MARK: - Default Implementation
extension ShiftSystemProtocol {
    
    // القيم الافتراضية (للحفاظ على التوافق ريثما نحدث الأنظمة)
    
    var workHoursPerShift: Int { 8 }
    
    var workDurationMinutes: Int {
        return workHoursPerShift * 60
    }
    
    var allowsFlexibility: Bool {
        return kind == .fixedWeek
    }
    
    var supportsFlexSettings: Bool {
        return allowsFlexibility
    }
    
    // ✅ التطبيق الافتراضي لمنطق الوقت (Fallback Logic)
    // هذا يضمن أن الأنظمة التي لم نحدثها بعد ستعمل بالمنطق القديم (8/16/0)
    
    func startOffset(for phase: ShiftPhase) -> Int {
        switch phase {
        case .morning: return 0
        case .evening: return 8
        case .night:   return 16
        default:       return 0
        }
    }
    
    func duration(for phase: ShiftPhase) -> Int {
        return workHoursPerShift
    }
}