import Foundation

/// ShiftStartOption
/// يمثل خيار "وضعك اليوم" أثناء الإعداد الأولي مع دعم الـ Index للتميز بين الأيام المكررة
struct ShiftStartOption: Identifiable, Hashable {
    
    // MARK: - Properties
    
    /// المعرف الفريد (ID) القادم من ShiftPhase.setupOptions
    let id: Int
    
    /// العنوان المعروض للمستخدم (مثل: "ثاني يوم ليل")
    let title: String
    
    /// نوع المناوبة المرتبطة (صباح، عصر، ليل، أوف)
    let phase: ShiftPhase
    
    // MARK: - Initializers
    
    /// لإنشاء خيار مع Index صريح (يستخدم في الأنظمة الدورية)
    init(id: Int, title: String, phase: ShiftPhase) {
        self.id = id
        self.title = title
        self.phase = phase
    }
    
    // MARK: - Static Helpers (للتوافق مع الكود القديم إذا لزم الأمر)
    
    /// دالة مساعدة لإنشاء الخيار بسهولة
    static func startWith(_ phase: ShiftPhase, id: Int, title: String) -> ShiftStartOption {
        return ShiftStartOption(id: id, title: title, phase: phase)
    }
    
    /// دالة احتياطية في حال كان النظام بسيطاً ولا يعتمد على IDs (للتوافق فقط)
    static func startWith(_ phase: ShiftPhase) -> ShiftStartOption {
        return ShiftStartOption(id: 0, title: phase.title, phase: phase)
    }
}
