import Foundation

/// نوع نظام النوبات من حيث البنية الزمنية
/// ❗️ملف وحيد ومركزي — يمنع التكرار أو التعارض
enum ShiftSystemKind {

    /// نظام يعتمد على دورة (A → B → C …)
    case cyclic

    /// نظام أسبوعي ثابت (مثال: الأحد–الخميس)
    case fixedWeek
    
}
